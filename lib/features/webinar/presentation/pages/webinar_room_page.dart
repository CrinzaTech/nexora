import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/live_playback.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/live_stream_controls.dart';
import 'package:nexora/core/widgets/pause_drain_banner.dart';
import 'package:nexora/core/widgets/draggable_fab.dart';
import 'package:nexora/features/courses/presentation/widgets/live_class_speed_dial.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_chat_panel.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_external_join.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_hand_raise_fab.dart';

/// The webinar room, **in the app**.
///
/// The learner is signed in and already an account, so entering is one
/// call: A3 takes the seat, and the payload it returns puts them either
/// in the lobby or straight into the class. No phone screen, no form, no
/// OTP, no webview — that is the website's flow, for visitors who have no
/// account to be recognised by.
class WebinarRoomPage extends StatelessWidget {
  final String slug;
  final String roomId;
  final String title;

  /// Cover art carried over from the card, so the lobby has something to
  /// show while waiting rather than a bare countdown on grey.
  final String? thumbnailUrl;
  final String? educatorName;

  /// Whether this seat was free. Carried from the detail screen because
  /// the room's own payloads (A3/A4) say nothing about price — and a
  /// **paid** webinar never puts its meeting link on screen to be
  /// copied. See [WebinarExternalJoinBody].
  final bool isFree;

  /// What the detail payload said about the join mode. A workshop or a
  /// meeting opens straight onto its own screen; only a streamed webinar
  /// goes through the lobby.
  final bool isStream;

  const WebinarRoomPage({
    super.key,
    required this.slug,
    required this.roomId,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
    this.isFree = false,
    this.isStream = true,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<WebinarRoomCubit>()
        ..enter(slug: slug, roomId: roomId, isStream: isStream),
      child: _WebinarRoomView(
        slug: slug,
        title: title,
        thumbnailUrl: thumbnailUrl,
        educatorName: educatorName,
        isFree: isFree,
      ),
    );
  }
}

class _WebinarRoomView extends StatefulWidget {
  /// Carried down only so a workshop's venue card can offer the entry
  /// pass, which is keyed by slug.
  final String slug;
  final String title;
  final String? thumbnailUrl;
  final String? educatorName;
  final bool isFree;

  const _WebinarRoomView({
    required this.slug,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
    this.isFree = false,
  });

  @override
  State<_WebinarRoomView> createState() => _WebinarRoomViewState();
}

class _WebinarRoomViewState extends State<_WebinarRoomView>
    with WidgetsBindingObserver {
  BetterPlayerController? _player;

  /// Which URL the current controller was built for. Guards against
  /// rebuilding the player on every unrelated state emission (a chat
  /// message arrives every few seconds during a busy class).
  String? _currentUrl;
  bool _preparing = false;

  /// Owned here, not by the controls: a signed URL that expires mid-webinar
  /// rebuilds the whole player, and a clock living inside it would restart
  /// the stream timer at zero every time it did.
  final LiveStreamClock _streamClock = LiveStreamClock();

  /// Whether the stream is currently muted for a speaking turn.
  bool _ducked = false;

  /// While the host's last words drain after a pause, a stall this long
  /// means the tail can't be fetched — end the drain rather than hang.
  Timer? _drainStallTimer;
  static const _drainStallLimit = Duration(seconds: 3);

  // The Dart-side join seek that used to live here is deleted — it was
  // the cause of the latency regression the sync feature appeared to
  // introduce. `value.duration` is a one-time snapshot from
  // `initialized`, but the seek could only run once the player was
  // actually playing, seconds later; it therefore landed
  // `startup elapsed + target` behind live rather than `target`.
  // `MediaItem.LiveConfiguration` / `configuredTimeOffsetFromLive` pick
  // the start position and hold it against the player's real live edge.
  // See live_class_page.dart for the full write-up.

  /// First `play` on the current controller. Realignment stays out of the
  /// way until the native live configuration has settled on its target.
  DateTime? _playbackStartedAt;
  static const _realignStartupGrace = Duration(seconds: 15);

  /// One live-offset placement per controller, seeked natively so the
  /// live edge is read fresh. See live_class_page.dart for why Dart
  /// cannot compute this correctly.
  bool _joinPlaced = false;
  bool _joinPlaceInFlight = false;
  int _joinPlaceTries = 0;
  static const _joinPlaceMaxTries = 20;

  // ── Post-interruption realignment ────────────────────────────────

  /// Drift smaller than this is left to the player's own speed control,
  /// which holds the native target offset continuously by nudging rate.
  /// A seek is only for the jump a long interruption leaves behind.
  static const _realignDeadband = Duration(seconds: 3);

  /// A seek on a live HLS stream costs a rebuffer, so two realignments
  /// close together feed each other. Nothing may seek again inside this
  /// window, whatever asks for it.
  DateTime? _lastRealignAt;
  static const _realignCooldown = Duration(seconds: 20);

  /// An interruption that cannot be corrected on the spot — app resume
  /// and error recovery, where the player needs a moment to come back
  /// before a seek means anything. The next progress tick consumes it:
  /// exactly one attempt, then it is gone, so this never becomes the
  /// periodic mid-playback correction that causes stutter.
  String? _pendingRealign;
  DateTime? _pendingRealignAt;
  static const _pendingRealignWindow = Duration(seconds: 8);

  /// The attendee pressed pause on this controller — the only thing that
  /// stops [_ensurePlaying] from re-asserting playback (the package never
  /// pauses on its own with `handleLifecycle` off).
  bool _userPaused = false;

  /// Delays the unmute after a speaking turn so the delayed HLS copy of
  /// the turn — the attendee's own voice included — plays out silently.
  /// Must stay equal to the cubit's `_postSpeakLinger`: LiveKit (carrying
  /// the host live) disconnects when that fires, and this unmute has to
  /// land at the same moment — unmuting first replays the echo tail,
  /// disconnecting first leaves the attendee in silence.
  Timer? _duckReleaseTimer;
  static const _duckReleaseDelay = Duration(seconds: 8);

  /// Landscape only: the chat panel slides in over the video rather
  /// than docking beside it, so the stage keeps the full screen.
  bool _chatOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A webinar is watched, not tapped.
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) return;
    // A suspended player keeps its own position while live time moves
    // on, and every device accumulates a different amount of that —
    // exactly the drift the shared target exists to remove. Nothing else
    // belongs here: the player's lifecycle is deliberately ours and not
    // the package's (`handleLifecycle: false`).
    _requestRealign('app resume');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _duckReleaseTimer?.cancel();
    _drainStallTimer?.cancel();
    // Restore the app-wide portrait lock from `main()`. Expanding the
    // stage pins landscape and keeps it pinned, so an attendee who backs
    // out mid-webinar would otherwise take that lock with them to every
    // other screen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    final controller = _player;
    _player = null;
    _currentUrl = null;
    _playbackStartedAt = null;
    _joinPlaced = false;
    _joinPlaceInFlight = false;
    _joinPlaceTries = 0;
    _lastRealignAt = null;
    _pendingRealign = null;
    _pendingRealignAt = null;
    controller?.dispose(forceDispose: true);
  }

  bool get _isLandscape =>
      mounted && MediaQuery.orientationOf(context) == Orientation.landscape;

  /// What the stage's expand button does, in place of the package's own
  /// fullscreen route.
  ///
  /// That route is pushed on the **root** navigator, so it sits outside
  /// this room's [BlocProvider] — the chat panel and the raise-hand dial
  /// cannot go inside it without re-providing the cubit and duplicating
  /// the whole landscape layout. Landscape here already drops the app bar
  /// and hands the whole screen to the stage, and it keeps chat and
  /// raise-hand with it.
  Future<void> _toggleLandscape() async {
    if (!mounted) return;
    // Stays pinned either way. Releasing it after the rotation settled
    // snapped straight back: the app is portrait-locked globally in
    // `main()`, and the attendee is still physically holding the phone
    // the way they were, so the moment we stop asking the OS puts it
    // back. This button is the only way in and out of landscape here, so
    // it has to hold. [dispose] restores the app-wide lock.
    await SystemChrome.setPreferredOrientations(
      _isLandscape
          ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  }

  /// Nothing to clear: this room's body already sits inside a [SafeArea]
  /// in both orientations, so the stage never reaches the navigation bar.
  double _stageBottomInset() => 0;

  Future<void> _syncPlayer(String hlsUrl) async {
    if (_preparing || _currentUrl == hlsUrl) return;
    _preparing = true;
    _disposePlayer();

    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        // We own the controller's lifecycle: the package otherwise
        // pauses on any visibility change (a dialog, a rotation) and a
        // live stream resumed from a paused position lands behind the
        // live edge.
        handleLifecycle: false,
        autoDispose: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enablePlaybackSpeed: false,
          enableSkips: false,
          // Read by [LiveStreamControls]: the bar is up when the stage
          // first comes alive, then fades out on its own a few seconds
          // later. Starting hidden would mean nobody sees the LIVE state
          // or the stream timer unless they think to tap the video.
          showControlsOnInitialize: true,
          progressBarPlayedColor: AppColors.primary,
          progressBarHandleColor: AppColors.primary,
          progressBarBufferedColor: AppColors.primary.withValues(alpha: 0.3),
          progressBarBackgroundColor: AppColors.grey200,
          // The package draws no progress row at all for a `liveStream`
          // source — its bottom bar swaps the row for the word "LIVE" and
          // stops there. [LiveStreamControls] replaces the whole bar with
          // the layout every streaming site uses: a full-width scrubber
          // with play / mute / LIVE + stream timer / expand beneath it.
          // Replacing the controls rather than drawing over them is also
          // what stops the two colliding — the package centres its icons
          // in that bar, so they reach right down to the bottom edge.
          playerTheme: BetterPlayerTheme.custom,
          customControlsBuilder: (controller, onVisibilityChanged) =>
              LiveStreamControls(
                controller: controller,
                clock: _streamClock,
                onControlsVisibilityChanged: onVisibilityChanged,
                bottomInset: _stageBottomInset(),
                isExpanded: _isLandscape,
                onToggleExpand: _toggleLandscape,
              ),
        ),
      ),
    );
    _player = controller;
    _currentUrl = hlsUrl;
    // Every fresh controller gets exactly one join-offset adjustment and
    // starts out playing.
    _playbackStartedAt = null;
    _joinPlaced = false;
    _joinPlaceInFlight = false;
    _joinPlaceTries = 0;
    _userPaused = false;
    _lastRealignAt = null;
    _pendingRealign = null;
    _pendingRealignAt = null;
    controller.addEventsListener(_onPlayerEvent);

    try {
      await controller.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          hlsUrl,
          liveStream: true,
          // MUST be explicit. Left null the Android side infers the
          // content type from the filename's extension, misses on
          // "master_<hash>.m3u8", and builds a progressive source that
          // every extractor then rejects.
          videoFormat: BetterPlayerVideoFormat.hls,
          // Every viewer holds the same distance behind the live edge.
          liveTargetOffsetMs: kLiveTargetOffsetMs,
          notificationConfiguration: BetterPlayerNotificationConfiguration(
            showNotification: true,
            title: widget.title,
            author: 'Webinar',
            notificationChannelName: 'Webinar',
            activityName: 'MainActivity',
          ),
          // Same segment maths as the live class: the publisher cuts
          // ~2s segments and the playlist window holds only a few, so
          // starting on less than a whole segment pins the player to the
          // live edge with no room to absorb a hiccup.
          bufferingConfiguration: const BetterPlayerBufferingConfiguration(
            // Sized against the live target, not independently: the
            // player can never hold more buffer than the distance to the
            // live edge, so a 4s offset with the old 4000/4000 pair asked
            // it to buffer the entire window before resuming from a stall
            // — which reads as a frozen player.
            //
            // ⚠️ ORDER IS ENFORCED. ExoPlayer's DefaultLoadControl.Builder
            // asserts, and THROWS on construction if violated:
            //     bufferForPlaybackMs              <= minBufferMs
            //     bufferForPlaybackAfterRebufferMs <= minBufferMs
            //     minBufferMs                      <= maxBufferMs
            // A throw here is not a degraded stream — the controller never
            // gets built, so the class cannot be joined at all. Keeping
            // minBufferMs equal to bufferForPlaybackAfterRebufferMs (as the
            // original 4000/4000 pair did) is the safe shape; scale the two
            // together if the live target changes again.
            minBufferMs: 2500,
            maxBufferMs: 8000,
            bufferForPlaybackMs: 1500,
            bufferForPlaybackAfterRebufferMs: 2500,
          ),
        ),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      // Required for raise-hand to work at all. Left alone, ExoPlayer and
      // AVPlayer hold exclusive audio focus and **pause** the moment the
      // WebRTC mic session takes it — the webinar would freeze for the
      // whole speaking turn. Mixing hands focus back to us; the stream is
      // quietened deliberately in [_applyDuck] instead.
      controller.setMixWithOthers(true);
      // Keep the mute if the player was rebuilt mid-turn.
      await controller.setVolume(_ducked ? 0.0 : 1.0);
      setState(() {});
    } catch (_) {
      // A signed URL that expired between resolve and setup is the
      // common case — ask for a fresh one rather than showing a dead
      // player.
      if (mounted) context.read<WebinarRoomCubit>().refreshPlayback();
    } finally {
      _preparing = false;
    }
  }

  /// Fully mutes the stream while this attendee holds the mic (the host
  /// is audible in real time over LiveKit instead — 0.2 still leaked the
  /// attendee's own delayed voice back at them). Mute is instant; the
  /// restore waits [_duckReleaseDelay] so the delayed HLS copy of the
  /// turn plays out silently first.
  Future<void> _applyDuck(bool duck) async {
    if (duck) {
      _duckReleaseTimer?.cancel();
      _duckReleaseTimer = null;
      if (_ducked) return;
      _ducked = true;
      await _player?.setVolume(0.0);
      return;
    }
    if (!_ducked || _duckReleaseTimer != null) return;
    _duckReleaseTimer = Timer(_duckReleaseDelay, () async {
      _duckReleaseTimer = null;
      if (!mounted) return;
      _ducked = false;
      final controller = _player;
      await controller?.setVolume(1.0);
      // iOS's audio category is process-wide, and the WebRTC session
      // that just ended may have re-asserted its own over ours — ask for
      // mixing again so the stream isn't left holding exclusive focus.
      controller?.setMixWithOthers(true);
    });
  }

  /// Put the playhead [kLiveTargetOffsetMs] behind the live edge, once
  /// per controller, seeked natively against a fresh live-edge reading.
  void _placeAtLiveOffset() {
    if (_joinPlaced || _joinPlaceInFlight || _userPaused) return;
    final hp = context.read<WebinarRoomCubit>().state.handPhase;
    if (hp == WebinarHandPhase.granted ||
        hp == WebinarHandPhase.connecting ||
        hp == WebinarHandPhase.speaking) {
      return; // never seek during a speaking turn
    }
    final inner = _player?.videoPlayerController;
    final value = inner?.value;
    if (inner == null || value == null || !value.initialized) return;
    if (!value.isPlaying) return;
    // Do NOT mark it done up front. The first attempts land before the
    // live window is readable and are skipped; burning the one shot on
    // those left the player wherever it started, which is what forced a
    // manual tap on "Go live".
    _joinPlaceInFlight = true;
    _joinPlaceTries++;
    unawaited(
      inner
          .seekToLiveOffset(kLiveTargetOffsetMs)
          .then((resultMs) {
            _joinPlaceInFlight = false;
            if (!mounted) return;
            // Only a real placement retires the attempt; a skip retries
            // on the next progress tick until the window is readable.
            if (resultMs >= 0 || _joinPlaceTries >= _joinPlaceMaxTries) {
              _joinPlaced = true;
            }
            const reasons = {
              -1: 'no live timeline yet',
              -2: 'window duration unknown',
              -3: 'already closer to live than target',
              -4: 'nothing buffered ahead yet',
            };
            debugPrint('[Webinar] join placement → '
                '${resultMs < 0 ? "skipped: ${reasons[resultMs] ?? resultMs}" : "${resultMs}ms behind live"}');
            _ensurePlaying();
          })
          .catchError((Object e) {
            _joinPlaceInFlight = false;
            // A platform that cannot answer must not be retried on every
            // progress tick for the whole class.
            if (_joinPlaceTries >= _joinPlaceMaxTries) _joinPlaced = true;
          }),
    );
  }

  /// Play by default. Re-asserts playback whenever the player is
  /// initialised and idle and the attendee has not pressed pause.
  void _ensurePlaying() {
    if (_userPaused) return;
    final inner = _player?.videoPlayerController;
    final value = inner?.value;
    if (inner == null || value == null) return;
    if (!value.initialized || value.isPlaying || value.isBuffering) return;
    if (value.hasError) return;
    if (context.read<WebinarRoomCubit>().state.pauseDraining) return;
    unawaited(inner.play());
  }

  /// Re-seek to the shared live target after a *discrete* interruption.
  /// Distance behind live comes from the platform player itself
  /// (ExoPlayer's `getCurrentLiveOffset`), never from `value.duration` —
  /// that is a one-time snapshot from `initialized` and measuring against
  /// it is what made the old join seek overshoot. The correction is a
  /// relative jump forward by the excess, so it needs no absolute idea of
  /// where the live edge is.
  void _realignAfterInterruption(String reason) {
    if (_userPaused) return;
    final last = _lastRealignAt;
    if (last != null && DateTime.now().difference(last) < _realignCooldown) {
      return;
    }
    final startedAt = _playbackStartedAt;
    if (startedAt == null ||
        DateTime.now().difference(startedAt) < _realignStartupGrace) {
      return;
    }
    final cubit = context.read<WebinarRoomCubit>();
    if (cubit.state.pauseDraining) return;
    final hp = cubit.state.handPhase;
    if (hp == WebinarHandPhase.granted ||
        hp == WebinarHandPhase.connecting ||
        hp == WebinarHandPhase.speaking) {
      // Never seek during a speaking turn: the conversation is real-time
      // over LiveKit and the HLS copy is ducked anyway.
      return;
    }
    final controller = _player;
    final inner = controller?.videoPlayerController;
    if (controller == null || inner == null) return;
    if (!inner.value.initialized || !inner.value.isPlaying) return;
    unawaited(
      inner.liveOffsetMs
          .then((offsetMs) {
            if (!mounted || offsetMs < 0) return;
            final excessMs = offsetMs - kLiveTargetOffsetMs;
            if (excessMs < _realignDeadband.inMilliseconds) return;
            final value = inner.value;
            if (!value.initialized || !value.isPlaying || _userPaused) return;
            _lastRealignAt = DateTime.now();
            debugPrint('[Webinar] realign ($reason): ${offsetMs}ms behind '
                'live (target ${kLiveTargetOffsetMs}ms) → +${excessMs}ms');
            unawaited(
              controller
                  .seekTo(value.position + Duration(milliseconds: excessMs))
                  .then((_) {
                    if (mounted) _ensurePlaying();
                  }),
            );
          })
          .catchError((Object _) {}),
    );
  }

  /// Queue a realignment for the moment the player is running again.
  /// Used where the interruption ends before the player has caught up —
  /// on resume or a URL re-resolve it may still be paused or buffering,
  /// and a seek against that position would be measured from a stale
  /// reading.
  void _requestRealign(String reason) {
    _pendingRealign = reason;
    _pendingRealignAt = DateTime.now();
    _consumePendingRealign();
  }

  /// One attempt, taken as soon as the player is genuinely playing, and
  /// dropped if it never gets there inside [_pendingRealignWindow] — by
  /// then a rebuilt controller owns the position instead.
  void _consumePendingRealign() {
    final reason = _pendingRealign;
    final since = _pendingRealignAt;
    if (reason == null || since == null) return;
    if (DateTime.now().difference(since) > _pendingRealignWindow) {
      _pendingRealign = null;
      _pendingRealignAt = null;
      return;
    }
    final value = _player?.videoPlayerController?.value;
    if (value == null || !value.initialized) return;
    if (!value.isPlaying || value.isBuffering) return;
    _pendingRealign = null;
    _pendingRealignAt = null;
    _realignAfterInterruption(reason);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    final cubit = context.read<WebinarRoomCubit>();
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.exception:
        if (cubit.state.pauseDraining) {
          // The tail couldn't be fetched (an old server still deletes the
          // playlist on stop) — nothing left to play, go to the lobby.
          cubit.finishDrain();
          return;
        }
        // Signed links are short-lived; a mid-session failure is usually
        // an expired one. Re-resolve instead of stranding the learner.
        cubit.refreshPlayback();
        // If that comes back with the same URL the controller is kept and
        // resumes wherever it died — which is behind the shared target.
        // (A changed URL rebuilds the player, and the join offset places
        // it; this request then falls away in the deadband.)
        _requestRealign('error recovery');
      case BetterPlayerEventType.finished:
        // Reached `#EXT-X-ENDLIST`: the host stopped and the attendee has
        // heard everything that was in flight.
        cubit.onPlayerFinished();
      case BetterPlayerEventType.bufferingStart:
        // Only matters mid-drain; the timer checks the flag when it fires
        // so a routine rebuffer costs nothing.
        _drainStallTimer?.cancel();
        _drainStallTimer = Timer(_drainStallLimit, () {
          if (!mounted) return;
          final c = context.read<WebinarRoomCubit>();
          if (c.state.pauseDraining) c.finishDrain();
        });
      case BetterPlayerEventType.bufferingEnd:
        _drainStallTimer?.cancel();
        _drainStallTimer = null;
        _ensurePlaying();
        _placeAtLiveOffset();
        // Deliberately NOT a realign point — a seek on a live stream
        // costs a rebuffer, so realigning from the end of one loops with
        // no exit. See the live-class page for the field symptom.
      case BetterPlayerEventType.play:
        _userPaused = false;
        _playbackStartedAt ??= DateTime.now();
        _placeAtLiveOffset();
      case BetterPlayerEventType.pause:
        _userPaused = true;
      case BetterPlayerEventType.progress:
        if (!_joinPlaced) _placeAtLiveOffset();
        // Never a correction of its own — only the delivery point for a
        // realignment an earlier interruption already asked for.
        _consumePendingRealign();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WebinarRoomCubit, WebinarRoomState>(
      listenWhen: (p, c) =>
          p.hlsUrl != c.hlsUrl ||
          p.phase != c.phase ||
          p.transientNotice != c.transientNotice ||
          p.handPhase != c.handPhase ||
          p.speakingUserId != c.speakingUserId,
      listener: (context, state) {
        final url = state.hlsUrl;
        if (url != null && state.phase == WebinarPhase.live) {
          _syncPlayer(url);
        } else if (state.phase != WebinarPhase.live &&
            state.phase != WebinarPhase.connecting) {
          // Lobby (host paused), ended, cancelled: drop the controller.
          // `_syncPlayer` short-circuits on an unchanged URL, so without
          // this a return to live would resume the stale, stuck player
          // instead of rebuilding at the new live edge. `connecting` is
          // spared — it is the URL refresh mid-session.
          _disposePlayer();
        }
        final myId = context.read<WebinarRoomCubit>().myId;
        // Mute from the GRANT, not from the `nowSpeaking` echo: the
        // LiveKit room (and the host's real-time voice) connects during
        // granted/connecting, and letting the delayed HLS stream overlap
        // it plays the host twice.
        _applyDuck(
          state.isSelfSpeaking(myId) ||
              state.handPhase == WebinarHandPhase.granted ||
              state.handPhase == WebinarHandPhase.connecting ||
              state.handPhase == WebinarHandPhase.speaking,
        );
        final notice = state.transientNotice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
          context.read<WebinarRoomCubit>().clearNotice();
        }
      },
      builder: (context, state) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        return Scaffold(
          backgroundColor: AppColors.white,
          // Landscape gives the whole screen to the stage — an app bar
          // there costs a strip of height the 16:9 video needs.
          appBar: isLandscape
              ? null
              : CustomAppBar(title: widget.title, centerTitle: false),
          body: SafeArea(
            child: isLandscape
                ? _landscape(context, state)
                : _portrait(context, state),
          ),
        );
      },
    );
  }

  // ── Layout ───────────────────────────────────────────────────────

  /// Stage on top, chat filling the rest, with the hand-raise button
  /// floating over the chat.
  ///
  /// The button lives over the chat rather than over the video on
  /// purpose: the player's own controls (play/pause, fullscreen) occupy
  /// the video's bottom corners, and anything parked there fights them.
  Widget _portrait(BuildContext context, WebinarRoomState state) {
    if (state.phase == WebinarPhase.joining) {
      return const Center(child: CircularProgressIndicator());
    }

    // Zoom, Meet and workshops have no player and no chat, so there is
    // no stage to pin to the top and nothing to fill the rest with —
    // they get the whole screen for the one thing they do have.
    if (state.phase == WebinarPhase.external) {
      return WebinarExternalJoinBody(
        state: state,
        title: widget.title,
        thumbnailUrl: widget.thumbnailUrl,
        educatorName: widget.educatorName,
        isFree: widget.isFree,
        // A paid workshop issues an entry pass; the venue card is where
        // an attendee already goes looking for "what do I do on the
        // day", so the way to their ticket belongs beside it.
        slug: widget.slug,
      );
    }

    return Column(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _stage(context, state)),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: WebinarChatPanel(
                  myId: context.read<WebinarRoomCubit>().myId,
                ),
              ),
              if (_showHandRaise(state))
                Positioned.fill(
                  child: DraggableFab(
                    // Fixed logical pixels, not Screen.* — those scale
                    // against a portrait design frame, which collapses
                    // the bottom inset and drops the button onto the
                    // chat composer.
                    margin: const EdgeInsets.only(
                      left: 16,
                      top: 16,
                      right: 16,
                      bottom: 76,
                    ),
                    builder: (context, _) => WebinarHandRaiseFab(state: state),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Landscape hands the whole screen to the stage.
  ///
  /// The portrait column cannot survive here: a 16:9 box at the full
  /// width of a landscape screen is taller than the screen itself, so
  /// stacking chat under it overflows by whatever the difference is.
  /// Chat becomes an overlay panel instead, and the controls collapse
  /// into a speed dial that drags anywhere — parked over the video, it
  /// is always covering something.
  Widget _landscape(BuildContext context, WebinarRoomState state) {
    if (state.phase == WebinarPhase.joining) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.phase == WebinarPhase.external) {
      return WebinarExternalJoinBody(
        state: state,
        title: widget.title,
        thumbnailUrl: widget.thumbnailUrl,
        educatorName: widget.educatorName,
        isFree: widget.isFree,
        // A paid workshop issues an entry pass; the venue card is where
        // an attendee already goes looking for "what do I do on the
        // day", so the way to their ticket belongs beside it.
        slug: widget.slug,
      );
    }

    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width * 0.42).clamp(260.0, 380.0);
    final myId = context.read<WebinarRoomCubit>().myId;

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _stage(context, state),
            ),
          ),
        ),

        // Always mounted, just slid off-screen: messages keep arriving
        // and the scroll position survives opening and closing.
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
                child: Material(
                  elevation: 8,
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  clipBehavior: Clip.antiAlias,
                  child: WebinarChatPanel(myId: myId),
                ),
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: DraggableFab(
            // Clears the live control bar along the bottom of the stage —
            // parked at a flat 16 the dial sat straight on the scrubber
            // and the expand button.
            margin: const EdgeInsets.only(
              left: 16,
              top: 16,
              right: 16,
              bottom: LiveStreamControls.barHeight + 16,
            ),
            builder: (context, dockedTop) => LiveClassSpeedDial(
              heroTag: 'webinar-speed-dial',
              // Parked up top, fanning upward would run off-screen.
              expandDown: dockedTop,
              children: [
                if (_showHandRaise(state))
                  WebinarHandRaiseFab(state: state, mini: true),
                FloatingActionButton.small(
                  heroTag: 'webinar-chat-toggle',
                  backgroundColor: _chatOverlayOpen
                      ? AppColors.error
                      : AppColors.primary,
                  foregroundColor: AppColors.alwaysWhite,
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

  /// Raising a hand only means anything while the class is running —
  /// there is nobody to hear it before the host starts or after they
  /// finish.
  bool _showHandRaise(WebinarRoomState state) =>
      state.phase == WebinarPhase.live;

  /// The 16:9 box, whatever is currently in it. Returned without its own
  /// [AspectRatio] so each layout can size it: pinned to the top in
  /// portrait, centred in the free space in landscape.
  Widget _stage(BuildContext context, WebinarRoomState state) {
    switch (state.phase) {
      case WebinarPhase.joining:
        return ColoredBox(
          color: AppColors.videoPlayerBgColor,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.alwaysWhite),
          ),
        );

      case WebinarPhase.error:
        return _StageError(
          message: state.errorMessage ?? 'Something went wrong.',
          canRetry: state.canRetry,
          paymentRequired: state.paymentRequired,
        );

      // Handled a layer up, where it gets the whole screen rather than a
      // 16:9 box. Reached only if a rebuild races the phase change.
      case WebinarPhase.external:
        return const _StageMessage(
          icon: Icons.open_in_new_rounded,
          text: 'This webinar happens elsewhere.',
        );

      // Ended and cancelled keep the chat: it is a transcript, and
      // someone arriving late deserves to read what was said rather than
      // hit a dead end.
      case WebinarPhase.ended:
        return const _StageMessage(
          icon: Icons.check_circle_outline_rounded,
          text: 'This webinar has finished.',
          detail: 'The chat is still here to read.',
        );

      case WebinarPhase.cancelled:
        return const _StageMessage(
          icon: Icons.event_busy_rounded,
          text: 'This webinar was cancelled.',
        );

      case WebinarPhase.lobby:
      case WebinarPhase.connecting:
        return _Lobby(
          state: state,
          title: widget.title,
          thumbnailUrl: widget.thumbnailUrl,
          educatorName: widget.educatorName,
        );

      case WebinarPhase.live:
        final player = _player;
        final myId = context.read<WebinarRoomCubit>().myId;
        final isMeSpeaking =
            state.isSelfSpeaking(myId) ||
            state.handPhase == WebinarHandPhase.speaking;

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.videoPlayerBgColor,
                child: player == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.alwaysWhite,
                        ),
                      )
                    : BetterPlayer(controller: player),
              ),
            ),
            // Who has the floor. Shown for this attendee too — "You're
            // live" is the one thing someone with an open mic most needs
            // to be sure of.
            if (isMeSpeaking || state.isOtherSpeaking(myId))
              Positioned(
                left: 12,
                // Clear of the live control bar along the bottom edge.
                bottom: 72,
                child: WebinarSpeakingChip(
                  name: state.speakingName ?? 'Someone',
                  isMe: isMeSpeaking,
                ),
              ),
            // Host pressed Stop; the last ~7s are still playing out.
            if (state.pauseDraining)
              const Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Center(child: PauseDrainBanner()),
              ),
          ],
        );
    }
  }
}

/// The waiting room. Not decoration — attendees arrive early, and this is
/// the only screen telling them they are in the right place and the class
/// has not started.
class _Lobby extends StatelessWidget {
  final WebinarRoomState state;
  final String title;
  final String? thumbnailUrl;
  final String? educatorName;

  const _Lobby({
    required this.state,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
  });

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final connecting = state.phase == WebinarPhase.connecting;

    // No AspectRatio of its own — the caller sizes the stage, which is
    // pinned to the top in portrait and centred in landscape.
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CustomNetworkImage(
              url: thumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: const SizedBox.shrink(),
            ),
          // Scrim: the cover is a photo and the copy on top has to stay
          // legible whatever it happens to be.
          Container(color: AppColors.black.withValues(alpha: 0.62)),
          Center(
            child: Padding(
              padding: Screen.getPadding(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (connecting) ...[
                    SizedBox(
                      width: Screen.getSize(22),
                      height: Screen.getSize(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.alwaysWhite,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(12)),
                    Text(
                      'Starting the stream…',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                        fontSize: Screen.getFontSize(15),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.schedule_rounded,
                      color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                      size: Screen.getSize(34),
                    ),
                    SizedBox(height: Screen.getVerticalSize(10)),
                    // `message` is written by the backend for exactly
                    // this spot — shown verbatim rather than re-worded
                    // per status, because the server knows which case
                    // it is and the client's guess would drift.
                    Text(
                      session?.message.isNotEmpty == true
                          ? session!.message
                          : 'Waiting for the host to start.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeMedium.copyWith(
                        color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                        fontSize: Screen.getFontSize(14),
                        height: 1.4,
                      ),
                    ),
                    if (session != null &&
                        session.timeUntilStart > Duration.zero) ...[
                      SizedBox(height: Screen.getVerticalSize(14)),
                      _LobbyCountdown(session: session),
                    ],
                  ],
                  SizedBox(height: Screen.getVerticalSize(14)),
                  // "You're in" — the reassurance the lobby exists for.
                  Container(
                    padding: Screen.getPadding(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: Screen.getSize(14),
                          color: AppColors.alwaysWhite,
                        ),
                        SizedBox(width: Screen.getHorizontalSize(6)),
                        Text(
                          "You're in. This will start automatically",
                          style: AppTypography.bodyTextSmallSemiBold.copyWith(
                            color: AppColors.alwaysWhite,
                            fontSize: Screen.getFontSizeCapped(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticks the lobby countdown down every second off the payload's own
/// `startsInSeconds` plus locally-elapsed time, so a wrong device clock
/// can't show a class as already finished or never starting.
class _LobbyCountdown extends StatefulWidget {
  final WebinarSessionState session;

  const _LobbyCountdown({required this.session});

  @override
  State<_LobbyCountdown> createState() => _LobbyCountdownState();
}

class _LobbyCountdownState extends State<_LobbyCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.session.timeUntilStart;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.session.timeUntilStart);
    });
  }

  @override
  void didUpdateWidget(covariant _LobbyCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every poll hands back a fresh payload; count from that one.
    if (oldWidget.session != widget.session) {
      _remaining = widget.session.timeUntilStart;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      WebinarFormatting.countdown(_remaining),
      style: AppTypography.h4SemiBold.copyWith(
        color: AppColors.alwaysWhite,
        fontSize: Screen.getFontSizeCapped(24),
        letterSpacing: 1,
      ),
    );
  }
}

/// A short sentence filling the 16:9 stage — used for the ended and
/// cancelled phases, where the chat below stays readable.
class _StageMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? detail;

  const _StageMessage({required this.icon, required this.text, this.detail});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Center(
        child: Padding(
          padding: Screen.getPadding(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: Screen.getSize(34),
                color: AppColors.alwaysWhite.withValues(alpha: 0.85),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.alwaysWhite,
                  fontSize: Screen.getFontSize(15),
                ),
              ),
              if (detail != null) ...[
                SizedBox(height: Screen.getVerticalSize(6)),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.alwaysWhite.withValues(alpha: 0.75),
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The error phase, sized to the stage so the chat transcript below is
/// still reachable.
class _StageError extends StatelessWidget {
  final String message;
  final bool canRetry;

  /// A3 refused because this is a paid webinar they have not bought.
  /// The checkout lives on the detail screen, one pop away.
  final bool paymentRequired;

  const _StageError({
    required this.message,
    required this.canRetry,
    this.paymentRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Center(
        child: SingleChildScrollView(
          padding: Screen.getPadding(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: Screen.getSize(34),
                color: AppColors.alwaysWhite.withValues(alpha: 0.8),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                  fontSize: Screen.getFontSize(13),
                ),
              ),
              if (paymentRequired) ...[
                SizedBox(height: Screen.getVerticalSize(14)),
                SizedBox(
                  width: Screen.getHorizontalSize(180),
                  child: CustomActionButton(
                    isFormFilled: true,
                    name: 'Back to payment',
                    shouldAnimate: false,
                    // Not a retry: A3 will refuse identically until the
                    // payment verifies, and the screen that can take it
                    // is the one they came from. Opened by a deep link
                    // there is nothing behind this route, so that case
                    // goes to the detail screen directly.
                    onTap: (startLoading, stopLoading, btnState) {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      final slug = context.read<WebinarRoomCubit>().slug;
                      context.go(
                        '${AppRoutes.webinarDetail}'
                        '?slug=${Uri.encodeComponent(slug)}',
                      );
                    },
                  ),
                ),
              ] else if (canRetry) ...[
                SizedBox(height: Screen.getVerticalSize(14)),
                SizedBox(
                  width: Screen.getHorizontalSize(160),
                  child: CustomActionButton(
                    isFormFilled: true,
                    name: 'Retry',
                    shouldAnimate: false,
                    onTap: (startLoading, stopLoading, btnState) {
                      startLoading();
                      context.read<WebinarRoomCubit>().retry().whenComplete(
                        () => stopLoading(),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
