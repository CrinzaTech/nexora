import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:nexora/features/courses/data/services/live_class_audio_playback_service.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/moving_watermark.dart';
import 'package:nexora/features/courses/presentation/bloc/live_class_cubit.dart';
import 'package:nexora/features/courses/presentation/pages/live_class_chat_panel.dart';
import 'package:nexora/features/courses/presentation/widgets/draggable_fab.dart';
import 'package:nexora/features/courses/presentation/widgets/hand_raise_bar.dart';
import 'package:nexora/features/courses/presentation/widgets/live_class_speed_dial.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';

/// Live class experience: HLS playback + real-time chat + raise-hand →
/// speak, with explicit lifecycle states (never a bare spinner).
///
/// Player runs on `better_player_plus` (ExoPlayer/AVPlayer directly) so the
/// buffer window can be tuned for the low-latency HLS cadence, while still
/// giving up exclusive audio focus (`setMixWithOthers`) so the OS doesn't
/// pause the stream the moment the WebRTC/LiveKit mic session takes focus
/// for raise-hand → speak — the app ducks the HLS volume manually instead.
/// Real-time (SignalR + LiveKit) is driven by [LiveClassCubit]; this widget
/// only renders state and owns the video controller.
class LiveClassPage extends StatelessWidget {
  final String title;
  final String roomId;
  final int courseId;
  final int coursePurchasedId;
  final String nodeId;
  final bool activateWatermark;
  final DateTime? scheduledAt;

  const LiveClassPage({
    super.key,
    required this.title,
    required this.roomId,
    this.courseId = 0,
    this.coursePurchasedId = 0,
    this.nodeId = '',
    this.activateWatermark = false,
    this.scheduledAt,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<LiveClassCubit>()..enter(roomId, scheduledAt: scheduledAt),
      child: _LiveClassView(
        title: title,
        coursePurchasedId: coursePurchasedId,
        nodeId: nodeId,
        activateWatermark: activateWatermark,
      ),
    );
  }
}

class _LiveClassView extends StatefulWidget {
  final String title;
  final int coursePurchasedId;
  final String nodeId;
  final bool activateWatermark;

  const _LiveClassView({
    required this.title,
    required this.coursePurchasedId,
    required this.nodeId,
    required this.activateWatermark,
  });

  @override
  State<_LiveClassView> createState() => _LiveClassViewState();
}

class _LiveClassViewState extends State<_LiveClassView>
    with WidgetsBindingObserver {
  BetterPlayerController? _playerController;
  String? _currentUrl;

  /// Lets Flutter *move* the player element when the layout reparents it on
  /// rotation, instead of unmounting and rebuilding it (which would drop the
  /// video surface and restart playback mid-class).
  final GlobalKey _playerKey = GlobalKey();
  bool _preparing = false;
  bool _completionFired = false;
  bool _ducked = false;

  String _userName = '';
  String _phoneNumber = '';

  // ── Auto audio-only fallback state ───────────────────────────────
  LiveAudioHandler? _audioHandler;
  bool _switching = false; // guards concurrent handoffs

  // Video-health tracking (drives video → audio fallback).
  Timer? _healthTimer;
  DateTime? _bufferStart;
  final List<DateTime> _stalls = [];
  static const _singleStallLimit = Duration(seconds: 12);
  static const _stallWindow = Duration(seconds: 30);
  static const _stallCountLimit = 3;

  // Recovery tracking (audio → video).
  Timer? _recoveryTimer;
  DateTime? _audioSince;
  int _recoveryStreak = 0;
  int _recoveryBackoff = 1; // multiplies the check interval on failure
  static const _audioMinDwell = Duration(seconds: 30);
  static const _recoveryInterval = Duration(seconds: 25);

  bool _backgrounded = false;

  // ── Anti-thrash guards ───────────────────────────────────────────
  // Without these the fallback and the recovery chase each other: a fresh
  // video player always buffers for a moment, the stall detector reads that
  // as a bad network and drops to audio, recovery immediately climbs back,
  // and the cycle repeats — visible as the audio panel blinking in and out
  // while the video reloads over and over.

  /// When the current video player finished starting. Stall detection is
  /// suppressed until it has had a chance to fill its buffer.
  DateTime? _videoReadyAt;
  static const _videoWarmup = Duration(seconds: 12);

  /// Last audio↔video transition; a second one inside the cooldown is
  /// ignored so the modes can't oscillate.
  DateTime? _lastModeSwitchAt;
  static const _modeSwitchCooldown = Duration(seconds: 10);

  bool _within(DateTime? mark, Duration window) =>
      mark != null && DateTime.now().difference(mark) < window;

  /// Landscape only: chat floats over the video instead of docking, so it
  /// never eats into the stage.
  bool _chatOverlayOpen = false;

  PlaybackMode get _mode => context.read<LiveClassCubit>().state.playbackMode;

  /// Speaking (or about to) — suppress auto audio-teardown so we never
  /// disrupt the student's live mic. Resumes after they stop.
  bool get _speakingActive {
    final hp = context.read<LiveClassCubit>().state.handPhase;
    return hp == HandPhase.granted ||
        hp == HandPhase.connecting ||
        hp == HandPhase.speaking;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.coursePurchasedId > 0 &&
        widget.nodeId.isNotEmpty &&
        sl<ContentCompletionService>().isMarked(
          widget.coursePurchasedId,
          widget.nodeId,
        )) {
      _completionFired = true;
    }
    if (widget.activateWatermark) {
      sl<ProfileCubit>().state.maybeWhen(
        loaded: (p) => _setIdentity(p.name, p.phoneNumber),
        updated: (p) => _setIdentity(p.name, p.phoneNumber),
        updating: (p) => _setIdentity(p.name, p.phoneNumber),
        orElse: () {},
      );
    }
    // Belt-and-braces for the phase trigger below: BlocConsumer's
    // listener only sees *changes*, so a phase already past `loading` by
    // the time this view mounts would never reach it. Check the current
    // phase once on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phase = context.read<LiveClassCubit>().state.phase;
      if (phase == LiveViewPhase.waiting || phase == LiveViewPhase.live) {
        _fireJoinCompletion();
      }
    });
    // Pre-initialise audio_service WHILE FOREGROUND. Android 12+ blocks
    // starting a foreground service from the background, so the service
    // must exist before the app is backgrounded — otherwise background
    // audio never starts and the process gets frozen (dropping SignalR →
    // the student disappears from the admin panel).
    LiveAudioPlaybackService.instance().then((h) {
      _audioHandler = h;
      debugPrint('[LiveClass] audio_service pre-warmed');
    }).catchError((Object e) {
      debugPrint('[LiveClass] audio pre-warm failed: $e');
    });
  }

  void _setIdentity(String? name, String? phone) {
    _userName = name ?? '';
    _phoneNumber = phone ?? '';
  }

  /// Records the live-class node as consumed the first time the student
  /// is confirmed inside the room. Latching locally is safe — the
  /// service queues and retries a failed POST on its own.
  void _fireJoinCompletion() {
    if (_completionFired) return;
    _completionFired = true;
    sl<ContentCompletionService>().markCompleted(
      coursePurchasedId: widget.coursePurchasedId,
      jsonContentId: widget.nodeId,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<LiveClassCubit>();
    final isLive = cubit.state.phase == LiveViewPhase.live;
    debugPrint('[LiveClass] lifecycle=$state live=$isLive mode=$_mode '
        'speaking=$_speakingActive');

    switch (state) {
      case AppLifecycleState.inactive:
        // Deliberately does nothing. `inactive` is NOT backgrounding — it
        // also fires for rotation, the player's fullscreen route, and any
        // system overlay that steals focus. Pulling down the notification
        // shade or quick settings holds the app in `inactive` for as long
        // as it stays open, with no `paused` ever following, so a timer
        // here (this used to debounce 400ms) fired every time and dropped
        // students into audio-only just for checking their notifications.
        //
        // Real backgrounding always reaches `hidden`/`paused` — measured
        // ~1s behind `inactive` on screen-off, which is still inside the
        // window where Android permits starting a foreground service.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Confirmed background — this is the only trigger for the handoff.
        _enterBackground();
      case AppLifecycleState.resumed:
        _backgrounded = false;
        if (isLive) {
          // Fresh signed URL (old one may be near expiry) + hub re-sync.
          cubit.refreshPlayback();
          if (_mode == PlaybackMode.audio && !_speakingActive) {
            // Monitor first: the immediate attempt can be deferred by the
            // mode cooldown, and the background handoff never starts a
            // monitor of its own — without this the student would sit on
            // audio with nothing left to retry.
            //
            // A handoff still in flight needs no help here; _switchToAudio
            // re-checks `_backgrounded` when it lands and recovers itself.
            _startRecoveryMonitor();
            _attemptRecovery(force: true);
          }
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Commit the background handoff: keep the class alive on audio-only so
  /// audio keeps playing (foreground service) and the process stays alive
  /// (SignalR stays connected → student stays in the admin panel).
  void _enterBackground() {
    if (!mounted) return;
    _backgrounded = true;
    final isLive =
        context.read<LiveClassCubit>().state.phase == LiveViewPhase.live;
    if (isLive && _mode == PlaybackMode.video && !_speakingActive) {
      debugPrint('[LiveClass] backgrounding → switch to audio');
      _switchToAudio(background: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthTimer?.cancel();
    _recoveryTimer?.cancel();
    // Let the screen sleep normally again once we leave the class.
    WakelockPlus.disable();
    // Restore the app-wide portrait lock from main(). Entering the player's
    // fullscreen sets DeviceOrientation.values and never puts it back, so
    // without this every screen stays rotatable after one live class.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _disposeControllers();
    // Stop (but don't dispose) the shared audio handler so no audio /
    // media notification lingers after leaving the class.
    _audioHandler?.releaseSession();
    super.dispose();
  }

  /// Keep the screen awake only while the class is actually live.
  void _setWakelock(bool enable) {
    if (_wakelockOn == enable) return;
    _wakelockOn = enable;
    enable ? WakelockPlus.enable() : WakelockPlus.disable();
  }

  bool _wakelockOn = false;

  void _disposeControllers() {
    _healthTimer?.cancel();
    final controller = _playerController;
    _playerController = null;
    _currentUrl = null;
    _bufferStart = null;
    _stalls.clear();
    if (controller != null) {
      controller.removeEventsListener(_onPlayerEvent);
      controller.pause();
      // forceDispose overrides `autoDispose: false` above — that flag stops
      // the widget from tearing down a controller we still need, but this
      // is the one place teardown is actually meant to happen.
      controller.dispose(forceDispose: true);
    }
  }

  Future<void> _syncPlayer(String hlsUrl) async {
    if (_preparing || _currentUrl == hlsUrl) return;
    _preparing = true;
    _disposeControllers();
    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        // We own the lifecycle. Left on (the default), the package pauses
        // playback on `AppLifecycleState.paused` AND whenever its
        // VisibilityDetector reports the surface as hidden — e.g. behind
        // the "Leave live class?" dialog. On a live stream a pause/resume
        // resumes from the stale paused position, dropping the student
        // behind the live edge and undoing the buffer tuning below.
        // [didChangeAppLifecycleState] already handles backgrounding by
        // handing off to audio-only.
        handleLifecycle: false,
        // We own this controller, so the widget must not dispose it.
        // Rotating rebuilds the stage under a different parent (Column in
        // portrait, Stack in landscape), which unmounts the BetterPlayer
        // widget — and its State.dispose() calls controller.dispose().
        // The controller died on every rotation while `_currentUrl` still
        // matched, so _syncPlayer short-circuited and the class sat on a
        // spinner forever. Teardown is [_disposeControllers]'s job.
        autoDispose: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enablePlaybackSpeed: false,
          enableSkips: false,
          showControlsOnInitialize: false,
          progressBarPlayedColor: AppColors.primary,
          progressBarHandleColor: AppColors.primary,
          progressBarBufferedColor: AppColors.primary.withValues(alpha: 0.3),
          progressBarBackgroundColor: AppColors.grey200,
        ),
      ),
    );
    _playerController = controller;
    _currentUrl = hlsUrl;
    controller.addEventsListener(_onPlayerEvent);
    try {
      await controller.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          hlsUrl,
          liveStream: true,
          // MUST be explicit. Left null, the package's Android side calls
          // `Util.inferContentTypeForExtension(uri.lastPathSegment)` — but
          // that Media3 helper switches on a bare extension ("m3u8"), and
          // it's handed the whole filename ("master_<hash>.m3u8"), so it
          // falls through to CONTENT_TYPE_OTHER and builds a
          // ProgressiveMediaSource instead of an HlsMediaSource. The
          // playlist is then parsed as a raw media file and every
          // extractor rejects it (UnrecognizedInputFormatException).
          videoFormat: BetterPlayerVideoFormat.hls,
          // Gives the player its own MediaSession. Android pauses an
          // app's AudioTrack on backgrounding unless the playback is tied
          // to a media session — the logs showed our track being paused
          // 200ms BEFORE our own lifecycle handler even ran, which is why
          // background audio was silent no matter what we played.
          notificationConfiguration: BetterPlayerNotificationConfiguration(
            showNotification: true,
            title: widget.title,
            author: 'Live class',
            notificationChannelName: 'Live class',
            activityName: 'MainActivity',
          ),
          // Sized against the segments the server ACTUALLY emits, which is
          // what matters here — not the cadence the latency brief assumed.
          //
          // The brief's values (min 2000 / playback 1000) were written for
          // 1s segments. The publisher still sends keyframes every 2s, so
          // SRS cuts ~2.1s segments and `hls_window 6` leaves only three of
          // them (~6.3s) in the playlist. Asking the player to start on less
          // than one whole segment pinned it to the live edge with no room
          // to absorb a hiccup: one audio-sink reset and it fell off the
          // back of the window, stalled past the 12s limit, and dropped to
          // audio-only. Hold ~2 segments instead.
          //
          // Revert to the brief's tighter numbers once the publisher's
          // keyframe interval is actually 1s — then a 6s window holds six
          // segments and the aggressive values work as intended.
          bufferingConfiguration: const BetterPlayerBufferingConfiguration(
            minBufferMs: 4500,
            maxBufferMs: 12000,
            bufferForPlaybackMs: 2500,
            bufferForPlaybackAfterRebufferMs: 4000,
          ),
        ),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      // CRITICAL for the raise-hand → speak flow. Without this,
      // ExoPlayer/AVPlayer manages audio focus itself and PAUSES the
      // moment WebRTC takes focus for the mic — the class video froze for
      // the whole speaking turn. Mixing hands focus back to us; we duck
      // the stream manually in [_applyDuck] instead.
      controller.setMixWithOthers(true);
      // Restore/keep duck level in case we rebuilt while speaking.
      await controller.setVolume(_ducked ? 0.2 : 1.0);
      setState(() {});
      // Start the warm-up clock here: everything below this point counts as
      // "video is up", and the first few seconds of buffering are normal.
      _videoReadyAt = DateTime.now();
      _stalls.clear();
      _bufferStart = null;
      _startHealthMonitor();
    } catch (_) {
      if (mounted) _maybeFallbackToAudio('init failed');
    } finally {
      _preparing = false;
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.exception:
        // Deferred: reacting synchronously here mutates the listener list
        // `_postEvent` is mid-iteration over, which throws "Concurrent
        // modification during iteration" and masks the real error.
        scheduleMicrotask(_recoverFromPlayerError);
      case BetterPlayerEventType.bufferingStart:
        _bufferStart ??= DateTime.now();
      case BetterPlayerEventType.bufferingEnd:
        if (_bufferStart != null) {
          _stalls.add(DateTime.now());
          _bufferStart = null;
        }
      case BetterPlayerEventType.play:
        // Playing again — the stream recovered, so start the retry budget
        // fresh for any future error.
        _playerErrorRetries = 0;
        // Backstop for the phase-based trigger: if the student somehow
        // reached playback without passing through a waiting/live
        // transition this listener saw, they're unambiguously in.
        _fireJoinCompletion();
      case BetterPlayerEventType.hideFullscreen:
        // Leaving fullscreen, the package calls WakelockPlus.disable()
        // unconditionally — but the class is still live, so re-assert our
        // own wakelock or the screen starts sleeping mid-session.
        if (_wakelockOn) WakelockPlus.enable();
      default:
        break;
    }
  }

  /// Periodic check while in video mode: a single long stall or repeated
  /// stalls in a short window → fall back to audio-only. Runs off a timer
  /// (not just value-change ticks) so a *sustained* stall — which emits
  /// no further ticks — is still caught.
  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _mode != PlaybackMode.video) return;
      // Keep the audio fallback warm. A preload can be interrupted (a
      // return to video stops the player mid-load), and a cold source means
      // the next handoff has to fetch the playlist before making any sound.
      // No-ops once it's loaded.
      // Something outside the app paused us (audio-focus loss on older
      // Android, an iOS interruption when the mic session opened).
      // Scoped to the speaking window so it never fights a student who
      // deliberately hit pause on the player controls.
      final controller = _playerController;
      final videoValue = controller?.videoPlayerController?.value;
      if (_speakingActive &&
          videoValue != null &&
          videoValue.initialized &&
          !videoValue.isPlaying &&
          !videoValue.isBuffering &&
          !videoValue.hasError) {
        debugPrint('[LiveClass] player paused externally → resuming '
            '(speaking=$_speakingActive)');
        controller!.play();
      }
      // A single stall currently lasting too long.
      final bs = _bufferStart;
      if (bs != null && DateTime.now().difference(bs) > _singleStallLimit) {
        _maybeFallbackToAudio('long stall');
        return;
      }
      // Repeated stalls within the rolling window.
      _stalls.removeWhere(
        (t) => DateTime.now().difference(t) > _stallWindow,
      );
      if (_stalls.length >= _stallCountLimit) {
        _maybeFallbackToAudio('repeated stalls');
      }
    });
  }

  // ── Video → audio handoff ────────────────────────────────────────

  int _playerErrorRetries = 0;

  /// Recover from a player error by re-preparing at the live edge.
  ///
  /// The usual cause is not a bad network but a stale position: while the
  /// app is backgrounded the player is suspended, live time keeps moving,
  /// and on resume it asks for the segment it left off at — which has since
  /// rotated out of the playlist window and 404s. Retrying the same source
  /// (what the player's own "Try again" button does) asks for that same
  /// dead segment, which is why it appeared to do nothing. Re-preparing
  /// starts from the current live edge instead.
  ///
  /// Only falls back to audio if that keeps failing, which is the case
  /// where the network really is the problem.
  Future<void> _recoverFromPlayerError() async {
    if (!mounted || _switching) return;
    final url = context.read<LiveClassCubit>().state.hlsUrl;
    if (url == null || url.isEmpty) return;
    if (_playerErrorRetries >= 2) {
      debugPrint('[LiveClass] player error persists → audio-only');
      _maybeFallbackToAudio('player error');
      return;
    }
    _playerErrorRetries++;
    debugPrint('[LiveClass] player error → re-preparing at live edge '
        '(attempt $_playerErrorRetries)');
    _currentUrl = null; // force a rebuild rather than a no-op re-sync
    await _syncPlayer(url);
  }

  /// Bandwidth of the audio-only rendition as advertised in the master
  /// playlist (`#EXT-X-STREAM-INF:BANDWIDTH=64000`). Capping the player here
  /// leaves no video variant eligible, so ExoPlayer keeps audio alone.
  static const int _audioOnlyBitrate = 64000;

  /// Guarded entry point for the automatic fallback. Ignores the trigger
  /// when we're already in / switching to audio, when the student is
  /// speaking (never drop their mic), or when there's no audio URL.
  void _maybeFallbackToAudio(String reason) {
    if (_switching) return;
    if (_mode == PlaybackMode.audio ||
        _mode == PlaybackMode.switchingToAudio) {
      return;
    }
    if (_speakingActive) return;
    // A player that only just started is expected to buffer — reading that
    // as a failing network is what made the mode flicker on every resume.
    if (_within(_videoReadyAt, _videoWarmup)) {
      debugPrint('[LiveClass] fallback ignored ($reason) — video warming up');
      return;
    }
    // And never bounce straight back after a transition.
    if (_within(_lastModeSwitchAt, _modeSwitchCooldown)) {
      debugPrint('[LiveClass] fallback ignored ($reason) — mode just changed');
      return;
    }
    final audioUrl = context.read<LiveClassCubit>().state.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) return;
    debugPrint('[LiveClass] fallback → audio ($reason)');
    _switchToAudio(background: _backgrounded);
  }

  /// Drop to audio-only **without touching the player**.
  ///
  /// Rather than tearing the video player down and starting a second one, we
  /// cap the existing controller's video bitrate. ExoPlayer then picks the
  /// audio-only rendition out of the same master playlist and keeps playing
  /// through the switch — no teardown, no rebuild, no cold start, and the
  /// data rate drops from ~850 kbps to ~48 kbps on its own.
  ///
  /// This replaced a just_audio handoff that never produced sound: it could
  /// not load the audio-only rendition in any configuration, which is why
  /// audio mode was silent and why returning to video was slow (the player
  /// had to be rebuilt from scratch every time).
  Future<void> _switchToAudio({bool background = false}) async {
    if (_switching) {
      debugPrint('[LiveClass] switchToAudio skipped — handoff already running');
      return;
    }
    final controller = _playerController;
    if (controller == null) {
      debugPrint('[LiveClass] switchToAudio skipped — no player');
      return;
    }
    _switching = true;
    final cubit = context.read<LiveClassCubit>();
    try {
      // Hold the media session first: audio_service promotes itself to a
      // foreground service off this, and that is what stops Android freezing
      // the process once the screen goes off. Without it the player is
      // suspended and background audio dies regardless of who's playing.
      final handler = await LiveAudioPlaybackService.instance();
      _audioHandler = handler;
      await handler.holdSession(title: widget.title);

      // Cap to the audio rendition's advertised bandwidth. No video track
      // qualifies, so ExoPlayer keeps audio only.
      controller.setTrack(
        BetterPlayerAsmsTrack('', 0, 0, _audioOnlyBitrate, 0, '', ''),
      );
      debugPrint('[LiveClass] switched to audio-only (background=$background)');

      _audioSince = DateTime.now();
      _recoveryStreak = 0;
      _recoveryBackoff = 1;
      if (!mounted) return;
      cubit.setPlaybackMode(PlaybackMode.audio);
      _lastModeSwitchAt = DateTime.now();
      // Climb back automatically once we're visible again.
      if (!_backgrounded) {
        _startRecoveryMonitor();
        scheduleMicrotask(() => _attemptRecovery(force: true));
      }
    } catch (e) {
      debugPrint('[LiveClass] switchToAudio FAILED (bg=$background): $e');
      if (!mounted) return;
      // Nothing was torn down, so recovering is just lifting the cap again.
      controller.setTrack(BetterPlayerAsmsTrack.defaultTrack());
      cubit.setPlaybackMode(PlaybackMode.video);
    } finally {
      _switching = false;
    }
  }

  // ── Audio → video recovery ───────────────────────────────────────

  void _startRecoveryMonitor() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(_recoveryInterval, (_) {
      _attemptRecovery();
    });
  }

  /// Lightweight reachability probe; two clean passes (and past the min
  /// dwell) climb back to video. Backs off the interval on failure and
  /// never flaps.
  Future<void> _attemptRecovery({bool force = false}) async {
    if (!mounted || _switching || _mode != PlaybackMode.audio) return;
    if (_backgrounded && !force) return; // don't rebuild video in bg
    if (_speakingActive) return;
    // Don't climb back the instant we dropped — but only for the AUTOMATIC
    // attempts. `force` means the student just came back to the app, and
    // making them stare at the switching screen for the cooldown (then up to
    // another poll interval) is exactly the long wait this was reported as.
    // The cooldown exists to stop the fallback and recovery oscillating on
    // their own; a deliberate resume is not a loop.
    if (!force && _within(_lastModeSwitchAt, _modeSwitchCooldown)) {
      debugPrint('[LiveClass] recovery deferred — mode just changed');
      return;
    }
    final since = _audioSince;
    if (!force &&
        (since == null || DateTime.now().difference(since) < _audioMinDwell)) {
      return;
    }
    // Returning to the foreground skips the reachability probe too: the
    // student is looking at the screen, and a round-trip before we even
    // start rebuilding just adds to the wait.
    final ok = force ? true : await _mediaReachable();
    if (!ok) {
      _recoveryStreak = 0;
      // Back off up to ~4x so a persistently weak network isn't probed
      // aggressively.
      _recoveryBackoff = (_recoveryBackoff * 2).clamp(1, 4);
      _recoveryTimer?.cancel();
      _recoveryTimer = Timer.periodic(
        _recoveryInterval * _recoveryBackoff,
        (_) => _attemptRecovery(),
      );
      return;
    }
    _recoveryStreak++;
    if (force || _recoveryStreak >= 2) {
      _switchToVideo();
    }
  }

  /// Small ranged GET of the master playlist with a tight timeout — a
  /// cheap "is the media host comfortably reachable?" signal.
  Future<bool> _mediaReachable() async {
    final url = context.read<LiveClassCubit>().state.hlsUrl;
    if (url == null || url.isEmpty) return false;
    try {
      final res = await http
          .get(Uri.parse(url), headers: const {'Range': 'bytes=0-1023'})
          .timeout(const Duration(seconds: 4));
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Lift the audio-only cap. The player never stopped, so video comes back
  /// as soon as ExoPlayer fetches the next segment at full quality — no
  /// rebuild, which is what used to make returning from background slow.
  Future<void> _switchToVideo() async {
    if (_switching) return;
    final cubit = context.read<LiveClassCubit>();
    final controller = _playerController;
    _switching = true;
    _recoveryTimer?.cancel();
    try {
      if (controller == null) {
        // Player really is gone (we left and came back) — rebuild it.
        final hlsUrl = cubit.state.hlsUrl;
        if (hlsUrl == null || hlsUrl.isEmpty) return;
        cubit.setPlaybackMode(PlaybackMode.switchingToVideo);
        _currentUrl = null;
        await _syncPlayer(hlsUrl);
      } else {
        // Clearing all three constraints restores unrestricted selection.
        controller.setTrack(BetterPlayerAsmsTrack.defaultTrack());
        debugPrint('[LiveClass] audio cap lifted → video');
      }
      _stalls.clear();
      _bufferStart = null;
      // Give the ladder a moment to step back up before stall detection
      // starts judging it again.
      _videoReadyAt = DateTime.now();
      if (!mounted) return;
      cubit.setPlaybackMode(PlaybackMode.video);
      _lastModeSwitchAt = DateTime.now();
      // Foreground video doesn't need the media session; drop the
      // notification so it doesn't linger while the class is on screen.
      if (!_backgrounded) await _audioHandler?.releaseSession();
    } finally {
      _switching = false;
    }
  }

  /// Duck the HLS volume while I'm the live speaker so I don't hear my
  /// own delayed audio; restore on stop.
  Future<void> _applyDuck(bool duck) async {
    if (_ducked == duck) return;
    _ducked = duck;
    final controller = _playerController;
    await controller?.setVolume(duck ? 0.2 : 1.0);
    if (!duck) {
      // iOS's AVAudioSession category is process-wide — WebRTC's own
      // voice-chat session (opened for the speaking turn that just ended)
      // may have re-asserted its category over ours. Re-request mixing so
      // the HLS stream doesn't get left in an exclusive-focus state.
      controller?.setMixWithOthers(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    // Block the back gesture while the class is live so the student
    // gets a "you'll disconnect" confirmation first.
    final isLive = context.select<LiveClassCubit, bool>(
      (c) => c.state.phase == LiveViewPhase.live,
    );
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return PopScope(
      // Landscape intercepts too: back there means "leave landscape", not
      // "leave the class".
      canPop: !isLive && !isLandscape,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.videoPlayerBgColor,
        appBar: CustomAppBar(
          title: widget.title,
          centerTitle: true,
          titleColor: AppColors.white,
          backgroundColor: AppColors.videoPlayerBgColor,
          // Without this the chevron calls Navigator.pop directly, which
          // sidesteps PopScope entirely — it was dropping students out of a
          // live class with no confirmation at all.
          onBackPressed: _handleBack,
        ),
        body: BlocConsumer<LiveClassCubit, LiveClassState>(
          listenWhen: (prev, curr) =>
              prev.hlsUrl != curr.hlsUrl ||
              prev.phase != curr.phase ||
              prev.transientNotice != curr.transientNotice ||
              prev.isSelfSpeaking(context.read<LiveClassCubit>().myId) !=
                  curr.isSelfSpeaking(context.read<LiveClassCubit>().myId) ||
              (prev.handPhase == HandPhase.speaking) !=
                  (curr.handPhase == HandPhase.speaking),
          listener: (context, state) {
            final cubit = context.read<LiveClassCubit>();
            // Joining the room is what counts as consuming a live-class
            // node — not the video decoding. `waiting` means we resolved
            // the room and are sitting in the pre-roll for the host;
            // `live` means the stream is up. Either way the student is
            // in. Firing here also covers the audio-only fallback, which
            // never emits a BetterPlayer `play` event.
            if (state.phase == LiveViewPhase.waiting ||
                state.phase == LiveViewPhase.live) {
              _fireJoinCompletion();
            }
            // Player sync / teardown + screen-awake by phase. Only drive
            // the VIDEO controller while in video mode — when we've fallen
            // back to audio, a fresh hlsUrl (e.g. on resume) must NOT
            // silently rebuild the video pipeline.
            if (state.phase == LiveViewPhase.live && state.hlsUrl != null) {
              _setWakelock(true);
              if (state.playbackMode == PlaybackMode.video) {
                _syncPlayer(state.hlsUrl!);
              }
            } else if (state.phase != LiveViewPhase.live) {
              _disposeControllers();
              _audioHandler?.releaseSession();
              _setWakelock(false);
            }
            // Audio ducking follows self-speaking. `handPhase.speaking`
            // is the authority when the id comparison can't run (myId
            // unknown) — otherwise the student's own mic fights the HLS
            // stream at full volume.
            _applyDuck(state.isSelfSpeaking(cubit.myId) ||
                state.handPhase == HandPhase.speaking);
            // One-shot notices → snackbar.
            final notice = state.transientNotice;
            if (notice != null) {
              CustomSnackbar.info(
                context,
                title: 'Live class',
                message: notice,
              );
              cubit.clearNotice();
            }
          },
        builder: (context, state) {
          switch (state.phase) {
            case LiveViewPhase.loading:
              return const _CenteredSpinner(
                label: 'Connecting to the live class…',
              );
            case LiveViewPhase.waiting:
              return _WaitingView(scheduledAt: state.scheduledAt);
            case LiveViewPhase.ended:
              return const _MessageView(
                icon: Icons.event_available,
                message: 'This live session has ended.',
              );
            case LiveViewPhase.cancelled:
              return const _MessageView(
                icon: Icons.event_busy,
                message: 'This class was cancelled.',
              );
            case LiveViewPhase.kicked:
              return const _MessageView(
                icon: Icons.person_off,
                message: "You've been removed from this class by the host.",
              );
            case LiveViewPhase.error:
              return _MessageView(
                icon: Icons.sensors_off,
                message: state.errorMessage ?? 'Something went wrong.',
                onRetry: state.canRetry
                    ? () => context.read<LiveClassCubit>().retry()
                    : null,
              );
            case LiveViewPhase.live:
              return _buildLive(context, state);
          }
        },
        ),
      ),
    );
  }

  /// Back handling for both the system gesture and the app-bar chevron.
  ///
  /// In landscape, back drops out of landscape rather than out of the class
  /// — students reach for it expecting to undo the rotation, and losing the
  /// whole session instead is a nasty surprise mid-lesson.
  Future<void> _handleBack() async {
    if (!mounted) return;
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      await _returnToPortrait();
      return;
    }
    final leave = await _confirmLeave();
    if (leave && mounted) context.pop();
  }

  /// Rotate back to portrait, then hand rotation control back to the user.
  Future<void> _returnToPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Pinning portrait is what actually forces the rotation, but leaving it
    // pinned would trap the student — they could never get back to
    // landscape. Release once the device has settled into the new
    // orientation.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Confirmation before leaving a live class — going back disconnects
  /// the stream + chat + hand-raise.
  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave live class?'),
        content: const Text(
          "You're currently in a live class. If you go back you'll be "
          'disconnected from the stream and chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildLive(BuildContext context, LiveClassState state) {
    final myId = context.read<LiveClassCubit>().myId;
    // Media stage: video, an audio-only panel, or a brief switching
    // indicator — chosen by the current playback mode.
    final stage = _buildStageWithOverlays(state, myId);

    // Landscape gives the whole screen to the video — docking the chat
    // beside it both squeezed the stage and overflowed the old Column.
    // Controls collapse into a speed dial, and chat floats on demand.
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return _buildLandscape(context, state, myId, stage);
    }

    return Column(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: stage),
        // Chat, with the hand-raise control floating over it. Hand-raise
        // works in audio mode too — SignalR / LiveKit are independent of
        // the media pipeline — so it lives outside the stage.
        Expanded(child: _buildChatWithFab(state, myId)),
      ],
    );
  }

  Widget _buildLandscape(
    BuildContext context,
    LiveClassState state,
    int? myId,
    Widget stage,
  ) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width * 0.42).clamp(260.0, 380.0);

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(aspectRatio: 16 / 9, child: stage),
          ),
        ),

        // Chat as a floating panel rather than a docked column. Always
        // mounted (just slid off-screen) so messages keep streaming in and
        // the scroll position survives opening and closing.
        Positioned(
          top: 8,
          bottom: 8,
          right: 8,
          width: panelWidth,
          child: IgnorePointer(
            ignoring: !_chatOverlayOpen,
            child: AnimatedSlide(
              offset: _chatOverlayOpen ? Offset.zero : const Offset(1.1, 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _chatOverlayOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _floatingChatPanel(myId),
              ),
            ),
          ),
        ),

        // Draggable like the portrait control — it sits over the video, so
        // wherever it's parked it's covering something.
        Positioned.fill(
          child: DraggableFab(
            margin: const EdgeInsets.all(16),
            builder: (context, dockedTop) => LiveClassSpeedDial(
              // Parked up top, fanning upward would run off-screen.
              expandDown: dockedTop,
              children: [
                HandRaiseFab(state: state, myId: myId, mini: true),
                FloatingActionButton.small(
                  heroTag: 'live-class-chat-toggle',
                  backgroundColor: _chatOverlayOpen
                      ? AppColors.error
                      : AppColors.primary,
                  foregroundColor: AppColors.white,
                  tooltip: _chatOverlayOpen ? 'Hide chat' : 'Show chat',
                  onPressed: () =>
                      setState(() => _chatOverlayOpen = !_chatOverlayOpen),
                  child: Icon(
                    _chatOverlayOpen
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Chat card used by the landscape overlay — the panel itself is the
  /// same widget as portrait, wrapped in a dismissible surface.
  Widget _floatingChatPanel(int? myId) {
    return Material(
      elevation: 8,
      color: AppColors.videoPlayerBgColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: AppSizes.paddingM,
              top: AppSizes.paddingS,
              bottom: AppSizes.paddingS,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: AppSizes.iconS,
                  color: AppColors.alwaysWhite,
                ),
                SizedBox(width: Screen.getHorizontalSize(8)),
                Expanded(
                  child: Text(
                    'Class chat',
                    style: AppTypography.bodyTextSemiBold.copyWith(
                      color: AppColors.alwaysWhite,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.alwaysWhite),
                  tooltip: 'Hide chat',
                  onPressed: () => setState(() => _chatOverlayOpen = false),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.alwaysWhite.withValues(alpha: 0.12)),
          Expanded(child: LiveClassChatPanel(myId: myId)),
        ],
      ),
    );
  }

  /// Stage plus the passive "someone else has the mic" chip.
  Widget _buildStageWithOverlays(LiveClassState state, int? myId) {
    final speakingName = state.speakingName ?? 'Someone';
    return Stack(
      children: [
        Positioned.fill(child: _buildStage(state)),
        if (state.isOtherSpeaking(myId))
          Positioned(
            left: 10,
            top: 10,
            child: SpeakingChip(name: speakingName),
          ),
      ],
    );
  }

  /// Chat with the raise-hand FAB floating over it. Kept clear of the stage
  /// so it never fights the player's own controls (fullscreen / play-pause
  /// both sit in the video's bottom corners), and draggable because any
  /// fixed spot ends up covering someone's messages.
  Widget _buildChatWithFab(LiveClassState state, int? myId) {
    return Stack(
      children: [
        Positioned.fill(child: LiveClassChatPanel(myId: myId)),
        // Only the button takes hits — the surrounding Stack has no other
        // children, so taps in the empty area fall through to the messages.
        Positioned.fill(
          child: DraggableFab(
            // Fixed logical pixels, not Screen.* — those scale against a
            // portrait Figma frame (px * height / 812), so the bottom inset
            // would collapse and drop the button onto the composer.
            margin: const EdgeInsets.only(
              left: 16,
              top: 16,
              right: 16,
              bottom: 76,
            ),
            builder: (context, _) => HandRaiseFab(state: state, myId: myId),
          ),
        ),
      ],
    );
  }

  Widget _buildStage(LiveClassState state) {
    switch (state.playbackMode) {
      case PlaybackMode.switchingToAudio:
        return const _SwitchingView(label: 'Optimizing for your connection…');
      case PlaybackMode.switchingToVideo:
        return const _SwitchingView(label: 'Reconnecting video…');
      case PlaybackMode.audio:
        return _AudioModeView(title: widget.title);
      case PlaybackMode.video:
        final player = _playerController;
        final ready = player != null &&
            player.videoPlayerController?.value.initialized == true;
        return Container(
          color: AppColors.videoPlayerBgColor,
          child: ready
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    BetterPlayer(key: _playerKey, controller: player),
                    if (widget.activateWatermark)
                      IgnorePointer(
                        child: MovingWatermark(
                          name: _userName,
                          phone: _phoneNumber,
                        ),
                      ),
                  ],
                )
              : const _CenteredSpinner(label: 'Starting video…'),
        );
    }
  }
}

/// Brief inline indicator shown during a video↔audio handoff.
class _SwitchingView extends StatelessWidget {
  final String label;
  const _SwitchingView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.videoPlayerBgColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.alwaysWhite,
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          Text(
            label,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.alwaysWhite,
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio-only stage: class title, LIVE badge, and the "switched to audio"
/// note with auto-recover reassurance. Chat + raise-hand stay usable
/// below this.
class _AudioModeView extends StatelessWidget {
  final String title;
  const _AudioModeView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.videoPlayerBgColor,
      padding: EdgeInsets.symmetric(horizontal: Screen.getHorizontalSize(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headphones, color: AppColors.alwaysWhite, size: 28),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LIVE · AUDIO',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.alwaysWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          Text(
            'Weak network. Switched to audio only.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.alwaysWhite,
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(4)),
          Text(
            'Video resumes automatically when your connection improves.',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.alwaysWhite.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner with a label. A bare spinner on a black field reads as "broken
/// player"; saying what's happening makes the same wait feel intentional.
class _CenteredSpinner extends StatelessWidget {
  final String? label;
  const _CenteredSpinner({this.label});

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.alwaysWhite),
          if (text != null) ...[
            SizedBox(height: Screen.getVerticalSize(14)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Screen.getHorizontalSize(24),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.alwaysWhite.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly "not started yet" view with an optional live countdown.
class _WaitingView extends StatefulWidget {
  final DateTime? scheduledAt;
  const _WaitingView({this.scheduledAt});

  @override
  State<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<_WaitingView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.scheduledAt != null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String? get _countdown {
    final at = widget.scheduledAt;
    if (at == null) return null;
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return 'Starts in ${h}h ${m}m';
    if (m > 0) return 'Starts in ${m}m ${s}s';
    return 'Starts in ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Screen.getHorizontalSize(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: AppColors.primary),
            SizedBox(height: Screen.getVerticalSize(16)),
            Text(
              "The class hasn't started yet.\nYou'll join automatically when it begins.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.alwaysWhite,
              ),
            ),
            if (countdown != null) ...[
              SizedBox(height: Screen.getVerticalSize(12)),
              Text(
                countdown,
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
            SizedBox(height: Screen.getVerticalSize(24)),
            // Live indication that we're still polling, so the wait doesn't
            // look like a dead screen the student needs to back out of.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.alwaysWhite.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(10)),
                Text(
                  'Checking for the live stream…',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.alwaysWhite.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Terminal / error message view with an optional retry action.
class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _MessageView({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Screen.getHorizontalSize(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.error),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.alwaysWhite,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: Screen.getVerticalSize(16)),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
