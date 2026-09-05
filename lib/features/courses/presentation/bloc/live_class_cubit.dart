import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/jwt_utils.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/data/services/live_class_audio_service.dart';
import 'package:nexora/features/courses/data/services/live_class_hub_service.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_chat_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_playback_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_polls_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_stream_token_usecase.dart';

part 'live_class_state.dart';
part 'live_class_cubit.freezed.dart';

/// Orchestrates the full live-class session: HLS playback resolution,
/// the StreamApi SignalR hub (chat, moderation, lifecycle), and the
/// raise-hand → LiveKit speak flow. Drives one [LiveClassState] with an
/// explicit [LiveViewPhase] so the UI never shows a bare spinner.
class LiveClassCubit extends Cubit<LiveClassState> {
  final GetLiveClassPlaybackUseCase getLiveClassPlaybackUseCase;
  final GetStreamTokenUseCase getStreamTokenUseCase;
  final GetLiveClassChatUseCase getLiveClassChatUseCase;
  final GetLiveClassPollsUseCase getLiveClassPollsUseCase;
  final LiveClassAudioService audioService;
  final SessionService sessionService;

  LiveClassCubit({
    required this.getLiveClassPlaybackUseCase,
    required this.getStreamTokenUseCase,
    required this.getLiveClassChatUseCase,
    required this.getLiveClassPollsUseCase,
    required this.audioService,
    required this.sessionService,
  }) : super(const LiveClassState());

  String _roomId = '';
  LiveClassHubService? _hub;
  StreamSubscription<LiveClassHubEvent>? _hubSub;

  /// Safety net for the `connecting → speaking` transition. The mic track
  /// is already published and `MicActivated` acknowledged by the time it
  /// starts; if the server's `nowSpeaking` echo never lands (not sent to
  /// the speaker, or a field/name mismatch) the student would otherwise
  /// sit on "Connecting…" forever while actually being live.
  Timer? _speakingEchoTimer;
  static const _speakingEchoGrace = Duration(seconds: 4);

  /// Holds the LiveKit room open (mic released, listening only) for a
  /// moment after a speaking turn ends, so the student keeps hearing the
  /// educator live while the delayed HLS copy of the turn — their own
  /// voice included — plays out silently. Must stay equal to the page's
  /// `_duckReleaseDelay`: the page unmutes the stream when this
  /// disconnects LiveKit. The 8s covers glass-to-glass HLS latency
  /// (~2.1s segments × ~3 in the playlist window + 2.5–4.5s player
  /// buffer) — re-derive it if the segment length or the player's
  /// bufferingConfiguration changes.
  Timer? _micLingerTimer;
  static const _postSpeakLinger = Duration(seconds: 8);

  /// Polls for the stream actually going live while the student waits.
  Timer? _readinessTimer;
  static const _readinessInterval = Duration(seconds: 5);

  /// Watches the playlist while the class is LIVE. The hub only says
  /// `classEnded` when the host *ends* the class — a host who pauses or
  /// stops the broadcast sends nothing, the playlist just freezes, and
  /// the player sat on a spinner for good. Two consecutive dead reads
  /// (~20s) drop the student back to the waiting screen, whose readiness
  /// poll then pulls them in again the moment segments reappear.
  Timer? _livenessTimer;
  static const _livenessInterval = Duration(seconds: 10);
  /// Raised from 2. At a 10s interval, 2 strikes declared the host gone
  /// after only 20s — short enough that ordinary mobile flakiness, or a
  /// CDN serving one stale playlist, showed students a "host paused"
  /// screen mid-class. Observed firing three times in 90 seconds while
  /// the educator was broadcasting normally. 4 strikes = ~40s, still
  /// well inside a minute for a genuine pause.
  static const _deadStrikeLimit = 4;
  int _deadStrikes = 0;
  String? _lastFingerprint;
  bool _livenessProbeInFlight = false;
  DateTime? _lastVerifyAt;

  /// The playlist the watchdog last caught frozen. The readiness poll
  /// refuses to go live on it again byte-for-byte — seeing the same
  /// segments is not a restart, whatever the headers say.
  String? _frozenFingerprint;

  /// Hard cap on the pause drain: ≥ HLS glass-to-glass latency (~8s) + a
  /// segment + buffer. A student who has heard nothing for this long has
  /// nothing left to drain.
  Timer? _drainGuard;
  static const _maxDrain = Duration(seconds: 12);

  /// This student's own `app_user.id`, decoded from their access token —
  /// used to tell "about me" hub events apart from others'.
  int? get myId => JwtUtils.currentUserId(sessionService.token);

  bool get isSelfSpeaking => state.isSelfSpeaking(myId);

  // ── Entry / teardown ─────────────────────────────────────────────

  /// Enter a live class. [scheduledAt] (from the node's startDateTime)
  /// seeds the waiting-state countdown; null hides it.
  Future<void> enter(String roomId, {DateTime? scheduledAt}) async {
    _roomId = roomId;
    // `myId` decides which hub events are "about me" (speaking, flags).
    // A null here means the access token carries the user id under a
    // claim JwtUtils doesn't know — worth seeing in the log.
    // ignore: avoid_print
    print('[ClassHub] enter room=$roomId myId=$myId');
    emit(state.copyWith(phase: LiveViewPhase.loading, scheduledAt: scheduledAt));

    // 1) Mint the StreamApi token for the hub.
    final tokenResult = await getStreamTokenUseCase();
    final token = tokenResult.fold((_) => null, (t) => t);
    if (token == null) {
      // Hub is unavailable, but we can still try to show the stream.
      _emitError(
        tokenResult.fold((f) => f, (_) => null),
        fallback: 'Could not connect to the live class.',
      );
      return;
    }

    // 2) Open the hub (chat + lifecycle + moderation).
    await _connectHub(token);

    // 3) Resolve playback, backfill chat and pick up any open poll.
    await Future.wait([_loadPlayback(), _loadInitialChat(), _loadPolls()]);
  }

  Future<void> _connectHub(String token) async {
    await _teardownHub();
    final hub = LiveClassHubService(accessToken: token);
    _hub = hub;
    _hubSub = hub.events.listen(_onHubEvent);
    try {
      await hub.connect(_roomId, accessToken: token);
      emit(state.copyWith(hubConnected: hub.isConnected));
    } catch (e) {
      // Non-fatal for playback, but chat + hand-raise won't work. Make
      // it visible instead of silently no-op'ing every send/raise.
      emit(state.copyWith(
        hubConnected: false,
        transientNotice:
            "Couldn't connect to live chat. Check your connection.",
      ));
      // Loud log with the exact URL so a misconfigured host is obvious.
      // ignore: avoid_print
      print('[ClassHub] connect error url=${hub.hubUrl} → $e');
    }
  }

  Future<void> _teardownHub() async {
    await _hubSub?.cancel();
    _hubSub = null;
    await _hub?.dispose();
    _hub = null;
  }

  // ── Playback ─────────────────────────────────────────────────────

  Future<void> _loadPlayback() async {
    final result = await getLiveClassPlaybackUseCase(_roomId);

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      // The playback 410 now says WHICH "no media" case it is. Deny-list,
      // not allow-list: only `Ended` / `Cancelled` are terminal (ended
      // screen). `Paused`, `Scheduled`, `Ready`, `Live`, any value added
      // later — all mean "no media yet" → the waiting screen, showing the
      // server's own message ("The host has paused the stream." reads
      // very differently from "hasn't started yet"). A 410 with no status
      // at all (older backend) takes the plain path below.
      final sessionStatus = failure.maybeWhen(
        sessionStatus: (message, status) => (message, status),
        orElse: () => null,
      );
      if (sessionStatus != null) {
        final (message, status) = sessionStatus;
        if (_isTerminalStatus(status)) {
          await _onSessionClosed(status);
          return;
        }
        emit(state.copyWith(
          phase: LiveViewPhase.waiting,
          waitingMessage: message.isEmpty ? null : message,
          broadcastInterrupted: status.toLowerCase() == 'paused',
        ));
        _startReadinessPolling();
        return;
      }
      final status = _statusOf(failure);
      // 410 = not started / link expired → treat as "waiting" (we'll
      // auto-join on classStarted) rather than a hard error.
      if (status == 410) {
        emit(state.copyWith(phase: LiveViewPhase.waiting));
        _startReadinessPolling();
      } else {
        _emitError(failure);
      }
      return;
    }

    final playback = result.fold((_) => null, (p) => p)!;

    // The API hands out a signed URL as soon as the class exists — it does
    // NOT mean the teacher is broadcasting yet. Going straight to `live`
    // here is what left students staring at a black player: the playlist
    // has no segments, so the player has nothing to render (and eventually
    // errors into the audio fallback). Confirm the stream is actually
    // producing media first, and sit in the waiting UI until it is.
    //
    // Only on the way IN, though. This also runs on every app resume — which
    // Android fires on rotation — and demoting a class that's already live
    // over one transient probe failure dumped students back onto the
    // "checking for the live stream" spinner mid-lesson.
    if (state.phase != LiveViewPhase.live) {
      final ready = await _isStreamReady(playback.hlsUrl);
      if (!ready) {
        emit(state.copyWith(
          phase: LiveViewPhase.waiting,
          hlsUrl: playback.hlsUrl,
          audioUrl: playback.audioUrl,
        ));
        _startReadinessPolling();
        return;
      }
    }

    _readinessTimer?.cancel();
    emit(state.copyWith(
      phase: LiveViewPhase.live,
      hlsUrl: playback.hlsUrl,
      audioUrl: playback.audioUrl,
      broadcastInterrupted: false,
      waitingMessage: null,
      pauseDraining: false,
    ));
    _startLivenessWatchdog();
  }

  static bool _isTerminalStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'ended' || normalized == 'cancelled';
  }

  /// The server said the session is over (`Ended`) or was called off
  /// (`Cancelled`) when we asked for playback — same teardown as the hub's
  /// own `classEnded` / `classCancelled`, which a student opening the
  /// class from a stale course screen never receives.
  Future<void> _onSessionClosed(String status) async {
    _readinessTimer?.cancel();
    _livenessTimer?.cancel();
    _livenessTimer = null;
    final cancelled = status.toLowerCase() == 'cancelled';
    // ignore: avoid_print
    print('[ClassHub] playback refused: session $status');
    await _endAudio();
    await _teardownHub();
    emit(state.copyWith(
      phase: cancelled ? LiveViewPhase.cancelled : LiveViewPhase.ended,
      broadcastInterrupted: false,
    ));
  }

  /// Re-probe on a timer while waiting so the student is pulled into the
  /// class the moment the teacher goes live, without needing the hub's
  /// `classStarted` event (which we may miss if the hub dropped).
  void _startReadinessPolling() {
    _readinessTimer?.cancel();
    _readinessTimer = Timer.periodic(_readinessInterval, (_) async {
      if (isClosed || state.phase != LiveViewPhase.waiting) return;
      // Re-resolve rather than reusing the stored URL: signed links are
      // short-lived and the one minted at entry may have expired while
      // the student waited.
      await _loadPlayback();
    });
  }

  /// True when the playlist behind [url] is actually serving media —
  /// a rendition with segments that is still being written. Anything
  /// less (no variants, no `#EXTINF`, or a playlist nobody has touched
  /// for a few target durations) is "not yet", and the poll retries.
  Future<bool> _isStreamReady(String url) async {
    final (health, fingerprint) = await _probeStreamHealth(url);
    if (health != _StreamHealth.alive) return false;
    // Same segments the watchdog caught frozen: the writer is still
    // gone. Guards the case where the server sends no Last-Modified.
    if (fingerprint != null && fingerprint == _frozenFingerprint) {
      return false;
    }
    return true;
  }

  /// Rendition URLs from a master playlist: the first non-comment line after
  /// each `#EXT-X-STREAM-INF`, resolved against the master's own URL (SRS
  /// emits them relative, and the signature covers the whole directory).
  List<String> _variantUrls(String masterUrl, String body) {
    final base = Uri.parse(masterUrl);
    final lines = body.split('\n');
    final urls = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty || candidate.startsWith('#')) continue;
        urls.add(base.resolve(candidate).toString());
        break;
      }
    }
    return urls;
  }

  // ── Liveness while live ──────────────────────────────────────────

  void _startLivenessWatchdog() {
    _livenessTimer?.cancel();
    _deadStrikes = 0;
    _lastFingerprint = null;
    _frozenFingerprint = null;
    _livenessTimer = Timer.periodic(_livenessInterval, (_) {
      unawaited(_livenessTick());
    });
  }

  Future<void> _livenessTick() async {
    if (isClosed || state.phase != LiveViewPhase.live) {
      _livenessTimer?.cancel();
      _livenessTimer = null;
      return;
    }
    final url = state.hlsUrl;
    if (url == null || url.isEmpty || _livenessProbeInFlight) return;
    _livenessProbeInFlight = true;
    try {
      final (health, fingerprint) = await _probeStreamHealth(url);
      if (isClosed || state.phase != LiveViewPhase.live) return;
      switch (health) {
        case _StreamHealth.alive:
          // A playlist that is reachable but hasn't moved between two
          // reads 10s apart (segments are ~2s) is a publisher that went
          // away and left its files behind — as dead as a 404.
          if (fingerprint != null && fingerprint == _lastFingerprint) {
            _deadStrikes++;
          } else {
            _deadStrikes = 0;
          }
          _lastFingerprint = fingerprint;
        case _StreamHealth.dead:
          _deadStrikes++;
        case _StreamHealth.ended:
          // `classPaused` never reached us (hub down) but the playlist is
          // closed out: same thing — drain the tail, then wait.
          _beginDrain();
          return;
        case _StreamHealth.unreachable:
          // The student's own network — inconclusive, never a strike.
          break;
      }
      if (_deadStrikes >= _deadStrikeLimit) _onBroadcastLost();
    } finally {
      _livenessProbeInFlight = false;
    }
  }

  /// The page's escalation path: the player has errored out or stalled
  /// past its limits. Before that gets blamed on the network, check
  /// whether there is still a broadcast to play — a host who stopped the
  /// stream looks exactly like this from the player's side. Throttled so
  /// the 3s health tick can call it freely.
  Future<void> verifyBroadcast() async {
    if (isClosed || state.phase != LiveViewPhase.live) return;
    // The drain has its own stall rule (page-side, 3s) and hard cap.
    if (state.pauseDraining) return;
    final now = DateTime.now();
    final last = _lastVerifyAt;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastVerifyAt = now;
    final url = state.hlsUrl;
    if (url == null || url.isEmpty) return;
    final (health, _) = await _probeStreamHealth(url);
    if (isClosed || state.phase != LiveViewPhase.live) return;
    // `ended` here too: the player has already errored/stalled past its
    // limits, so there is nothing left to drain.
    if (health == _StreamHealth.dead || health == _StreamHealth.ended) {
      _onBroadcastLost();
    }
  }

  // ── Pause drain ──────────────────────────────────────────────────

  /// The host pressed Stop — but the student is ~7s behind, and the last
  /// sentence is still listed in the playlist and sitting in the player
  /// buffer. Cutting to the waiting screen now would throw it away (and,
  /// worse, an old controller that outlived the cut could play it later,
  /// after the restart). So: keep the player exactly as it is under a
  /// banner and let it run to the end of the stream. [finishDrain] ends
  /// it — on the player finishing, on a >3s stall while draining, or on
  /// the [_maxDrain] guard.
  void _beginDrain() {
    if (state.phase != LiveViewPhase.live || state.pauseDraining) return;
    // The watchdog would read the closed-out playlist as dead and cut to
    // waiting under us; the guard is the timeout while draining.
    _livenessTimer?.cancel();
    _livenessTimer = null;
    _drainGuard?.cancel();
    _drainGuard = Timer(_maxDrain, () {
      _drainGuard = null;
      finishDrain();
    });
    // ignore: avoid_print
    print('[ClassHub] host pausing → draining the buffered tail');
    emit(state.copyWith(pauseDraining: true));
  }

  /// The tail has been heard (player reached the end), can't be fetched
  /// (stalled), or the guard expired — now the waiting screen.
  void finishDrain() {
    if (!state.pauseDraining) return;
    _onBroadcastLost();
  }

  /// The page's player reached the end of the stream. While draining
  /// that is the precise moment the student has heard everything; outside
  /// a drain it means the playlist was closed out and the player got there
  /// before the watchdog did — nothing left to play either way.
  void onPlayerFinished() {
    if (state.pauseDraining) {
      finishDrain();
    } else if (state.phase == LiveViewPhase.live) {
      _onBroadcastLost();
    }
  }

  /// Back to the waiting screen, flagged as an interruption. The page
  /// tears the player down on the phase change, and the readiness poll
  /// re-resolves playback (fresh signed URL) and returns to `live` — a
  /// full player rebuild at the new live edge — once segments are back.
  void _onBroadcastLost() {
    _livenessTimer?.cancel();
    _livenessTimer = null;
    _drainGuard?.cancel();
    _drainGuard = null;
    _deadStrikes = 0;
    _frozenFingerprint = _lastFingerprint;
    // ignore: avoid_print
    print('[ClassHub] broadcast lost → waiting for the host to resume');
    emit(state.copyWith(
      phase: LiveViewPhase.waiting,
      broadcastInterrupted: true,
      pauseDraining: false,
      // Generic paused copy until the next poll brings the server's own.
      waitingMessage: null,
      // The player is gone with the phase; a mode still stuck on `audio`
      // from an earlier fallback would stop the page rebuilding video
      // when we come back.
      playbackMode: PlaybackMode.video,
    ));
    _startReadinessPolling();
  }

  /// Like [_isStreamReady] but tells "no broadcast" apart from "can't
  /// reach the server", and returns a fingerprint of the live variant
  /// (media sequence + newest segment) so a frozen playlist is detectable.
  Future<(_StreamHealth, String?)> _probeStreamHealth(
    String url, {
    int depth = 0,
  }) async {
    if (depth > 1) return (_StreamHealth.dead, null);
    final http.Response res;
    try {
      res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return (_StreamHealth.unreachable, null);
    }
    // 404/410: SRS cleaned the playlist up on unpublish, or the signed
    // link expired — either way nothing plays from this URL.
    if (res.statusCode != 200) return (_StreamHealth.dead, null);
    final body = res.body;
    if (!body.contains('#EXTM3U')) return (_StreamHealth.dead, null);

    if (body.contains('#EXT-X-STREAM-INF')) {
      var sawUnreachable = false;
      var sawEnded = false;
      for (final variant in _variantUrls(url, body).take(3)) {
        final (health, fp) = await _probeStreamHealth(variant, depth: depth + 1);
        if (health == _StreamHealth.alive) return (health, fp);
        if (health == _StreamHealth.unreachable) sawUnreachable = true;
        if (health == _StreamHealth.ended) sawEnded = true;
      }
      return (
        sawEnded
            ? _StreamHealth.ended
            : sawUnreachable
                ? _StreamHealth.unreachable
                : _StreamHealth.dead,
        null,
      );
    }
    if (!body.contains('#EXTINF')) return (_StreamHealth.dead, null);
    // Closed out with ENDLIST: the host stopped, and the server left the
    // tail playable so the student hears the last words. Its own verdict
    // — the watchdog drains on it rather than cutting to waiting.
    if (body.contains('#EXT-X-ENDLIST')) {
      return (_StreamHealth.ended, _fingerprint(body));
    }
    if (_isAbandoned(res, body)) return (_StreamHealth.dead, null);
    return (_StreamHealth.alive, _fingerprint(body));
  }

  /// A media playlist that nobody has rewritten for a few target
  /// durations. This is what the stream host serves after the educator
  /// stops: SRS leaves the last playlist and its window of segments on
  /// disk, nginx keeps answering 200 for them, there is no
  /// `#EXT-X-ENDLIST` — so on content alone it is indistinguishable from
  /// a live stream, and a player handed it plays the last few seconds
  /// of the old broadcast. `Last-Modified` against the server's own
  /// `Date` (no client clock involved) is what tells them apart. A live
  /// writer touches the playlist every segment (~1–2s); the threshold is
  /// 3× target duration + 3s. Missing headers → can't tell → not stale
  /// here; [_frozenFingerprint] covers that server.
  bool _isAbandoned(http.Response res, String body) {
    final written = _httpDate(res.headers['last-modified']);
    final serverNow = _httpDate(res.headers['date']);
    if (written == null || serverNow == null) return false;
    final target = int.tryParse(
          RegExp(r'#EXT-X-TARGETDURATION:(\d+)').firstMatch(body)?.group(1) ??
              '',
        ) ??
        2;
    final staleAfter = Duration(seconds: 3 * target.clamp(1, 10) + 3);
    return serverNow.difference(written) > staleAfter;
  }

  /// RFC 1123 (`Wed, 26 Aug 2026 14:54:20 GMT`). Not `HttpDate` from
  /// dart:io — this code also builds for web.
  static DateTime? _httpDate(String? value) {
    if (value == null) return null;
    try {
      return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
          .parseUtc(value.trim());
    } catch (_) {
      return null;
    }
  }

  String _fingerprint(String mediaPlaylist) {
    final lines = mediaPlaylist.split('\n');
    String sequence = '';
    String lastSegment = '';
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE')) {
        sequence = line;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        lastSegment = line;
      }
    }
    return '$sequence|$lastSegment';
  }

  /// Called by the page as it drives the video↔audio handoff so the UI
  /// (switching indicators / audio panel) reflects the current pipeline.
  void setPlaybackMode(PlaybackMode mode) {
    if (state.playbackMode != mode) {
      emit(state.copyWith(playbackMode: mode));
    }
  }

  /// Re-fetch a fresh signed URL (used on classStarted and on resume) and
  /// (re)enter the live phase.
  Future<void> refreshPlayback() => _loadPlayback();

  /// Retry after a hard error (Retry button).
  Future<void> retry() async {
    emit(state.copyWith(phase: LiveViewPhase.loading));
    if (_hub == null || !(_hub?.isConnected ?? false)) {
      final tokenResult = await getStreamTokenUseCase();
      final token = tokenResult.fold((_) => null, (t) => t);
      if (token != null) await _connectHub(token);
    }
    await _loadPlayback();
  }

  void _emitError(Failure? failure, {String? fallback}) {
    final status = failure == null ? null : _statusOf(failure);
    switch (status) {
      case 403:
        emit(state.copyWith(
          phase: LiveViewPhase.error,
          errorMessage: "You're not enrolled in this class.",
          canRetry: false,
        ));
        break;
      case 404:
        emit(state.copyWith(
          phase: LiveViewPhase.error,
          errorMessage: 'Class not found.',
          canRetry: false,
        ));
        break;
      case 410:
        emit(state.copyWith(
          phase: LiveViewPhase.error,
          errorMessage: "This class hasn't started or the link expired.",
          canRetry: true,
        ));
        break;
      case 503:
        emit(state.copyWith(
          phase: LiveViewPhase.error,
          errorMessage: 'Streaming temporarily unavailable.',
          canRetry: true,
        ));
        break;
      default:
        emit(state.copyWith(
          phase: LiveViewPhase.error,
          errorMessage: failure?.message ?? fallback ?? 'Something went wrong.',
          canRetry: true,
        ));
    }
  }

  int? _statusOf(Failure failure) => failure.maybeWhen(
        server: (_, statusCode) => statusCode,
        orElse: () => null,
      );

  // ── Chat ─────────────────────────────────────────────────────────

  Future<void> _loadInitialChat() async {
    final result = await getLiveClassChatUseCase(_roomId, limit: 30);
    result.fold(
      (failure) {
        // Don't swallow: history-fetch failures were invisible before.
        // ignore: avoid_print
        print('[ClassChat] history FETCH FAILED → ${failure.message}');
      },
      (messages) {
        // ignore: avoid_print
        print('[ClassChat] history fetched count=${messages.length}');
        emit(state.copyWith(
          messages: _sortNewestFirst(messages),
          chatHasMore: messages.length >= 30,
        ));
        _absorbPolls(messages);
      },
    );
  }

  /// Page backwards from the oldest message currently held.
  Future<void> loadMoreChat() async {
    if (state.chatLoadingMore || !state.chatHasMore) return;
    final oldest = state.messages.isEmpty ? null : state.messages.last.id;
    emit(state.copyWith(chatLoadingMore: true));
    final result =
        await getLiveClassChatUseCase(_roomId, beforeId: oldest, limit: 30);
    result.fold(
      (_) => emit(state.copyWith(chatLoadingMore: false)),
      (older) {
        final merged = [...state.messages, ..._sortNewestFirst(older)];
        emit(state.copyWith(
          messages: merged,
          chatLoadingMore: false,
          chatHasMore: older.length >= 30,
        ));
        _absorbPolls(older);
      },
    );
  }

  // ── Polls ────────────────────────────────────────────────────────

  /// Server-shaped polls are authoritative for this viewer (own answer
  /// filled in, counts if visible) — take them as-is.
  Future<void> _loadPolls() async {
    final result = await getLiveClassPollsUseCase(_roomId);
    if (isClosed) return;
    result.fold(
      (failure) {
        // An older server has no polls route; chat rows still seed them.
        // ignore: avoid_print
        print('[ClassPoll] list failed → ${failure.message}');
      },
      (polls) {
        if (polls.isEmpty) return;
        final map = Map<int, LivePoll>.from(state.polls);
        for (final p in polls) {
          map[p.id] = p;
        }
        emit(state.copyWith(polls: map));
      },
    );
  }

  /// Re-fetch — the card asks for this when a timed deadline passes with
  /// no `pollRevealed` in sight (hub hiccup).
  Future<void> refreshPolls() => _loadPolls();

  /// Seed the map from chat rows (history and live pushes both carry the
  /// poll). A row never overrides a fuller copy already held.
  void _absorbPolls(List<LiveChatMessage> messages) {
    Map<int, LivePoll>? map;
    for (final m in messages) {
      final poll = m.poll;
      if (poll == null) continue;
      map ??= Map<int, LivePoll>.from(state.polls);
      map[poll.id] = _mergePoll(map[poll.id], poll);
    }
    if (map != null) emit(state.copyWith(polls: map));
  }

  /// Incoming copies (a reveal, a re-fetched row) don't always carry this
  /// student's own choice — never lose it.
  LivePoll _mergePoll(LivePoll? existing, LivePoll incoming) {
    if (existing == null) return incoming;
    if (incoming.myOptionIds.isEmpty && existing.myOptionIds.isNotEmpty) {
      return incoming.copyWith(myOptionIds: existing.myOptionIds);
    }
    return incoming;
  }

  void _upsertPoll(LivePoll poll) {
    emit(state.copyWith(
      polls: {...state.polls, poll.id: _mergePoll(state.polls[poll.id], poll)},
    ));
  }

  void _patchPoll(int pollId, LivePoll Function(LivePoll) patch) {
    final poll = state.polls[pollId];
    if (poll == null) return;
    emit(state.copyWith(polls: {...state.polls, pollId: patch(poll)}));
  }

  /// Single-choice: exactly one id. Multiple: every ticked id, in one
  /// call — there is no second submission. The server enforces the same
  /// rules; the local check just saves a round trip for the obvious ones.
  Future<void> submitVote(int pollId, List<int> optionIds) async {
    final poll = state.polls[pollId];
    if (poll == null) return;
    if (optionIds.isEmpty || (!poll.isMultiple && optionIds.length != 1)) {
      emit(state.copyWith(transientNotice: 'Choose an option.'));
      return;
    }
    if (!(_hub?.isConnected ?? false)) {
      emit(state.copyWith(
        hubConnected: false,
        transientNotice: 'Not connected to the class. Try again in a moment.',
      ));
      return;
    }
    try {
      await _hub?.submitVote(pollId, optionIds);
    } catch (e) {
      emit(state.copyWith(transientNotice: "Couldn't submit your answer."));
      // ignore: avoid_print
      print('[ClassPoll] SubmitVote error → $e');
    }
  }

  Future<void> sendChat(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.flags.chatBlocked) return;
    if (!(_hub?.isConnected ?? false)) {
      emit(state.copyWith(
        hubConnected: false,
        transientNotice: 'Not connected to live chat. Message not sent.',
      ));
      return;
    }
    // ~1000 char cap (server also enforces).
    final capped = trimmed.length > 1000 ? trimmed.substring(0, 1000) : trimmed;
    try {
      await _hub?.sendChat(capped);
    } catch (e) {
      emit(state.copyWith(transientNotice: 'Message could not be sent.'));
      // ignore: avoid_print
      print('[ClassHub] SendChat error → $e');
    }
  }

  /// Newest-first ordering used everywhere (recent on top).
  List<LiveChatMessage> _sortNewestFirst(List<LiveChatMessage> list) {
    final copy = [...list]..sort((a, b) => b.id.compareTo(a.id));
    return copy;
  }

  /// Private mode: keep only educator + own messages. Applied to what's
  /// on screen when the mode flips to private.
  List<LiveChatMessage> _applyPrivateFilter(List<LiveChatMessage> list) {
    return list
        .where((m) => m.isEducator || m.senderId == myId)
        .toList();
  }

  // ── Hand-raise / speak ───────────────────────────────────────────

  Future<void> raiseHand() async {
    if (state.flags.handBlocked) return;
    if (!(_hub?.isConnected ?? false)) {
      emit(state.copyWith(
        hubConnected: false,
        transientNotice: 'Not connected to the class. Try again in a moment.',
      ));
      return;
    }
    try {
      await _hub?.raiseHand();
      // Optimistic; server confirms with queuePosition.
      emit(state.copyWith(handPhase: HandPhase.queued));
    } catch (e) {
      emit(state.copyWith(transientNotice: "Couldn't raise your hand."));
      // ignore: avoid_print
      print('[ClassHub] RaiseHand error → $e');
    }
  }

  Future<void> lowerHand() async {
    await _hub?.lowerHand();
    emit(state.copyWith(handPhase: HandPhase.idle, queuePosition: null));
  }

  /// User tapped "finish speaking".
  Future<void> stopSpeaking() async {
    await _hub?.stopSpeaking();
    // Normal turn end — the echo of the turn is still in flight on HLS.
    await _endAudio(lingerToCoverEcho: true);
  }

  /// Handles a mic grant: request permission NOW, connect LiveKit, and
  /// signal the hub the instant the local track is live.
  Future<void> _onMicGranted(MicGrantedEvent e) async {
    // A fresh grant during the post-turn linger window: cancel the
    // pending disconnect so it can't tear down the room this new turn is
    // about to (re)connect.
    _micLingerTimer?.cancel();
    _micLingerTimer = null;
    // A mic-blocked student is never granted server-side; guard anyway.
    if (state.flags.micBlocked) return;
    emit(state.copyWith(handPhase: HandPhase.granted));

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      emit(state.copyWith(
        handPhase: HandPhase.idle,
        transientNotice: 'Microphone permission is needed to speak.',
      ));
      // Release the grant so the queue moves on.
      await _hub?.stopSpeaking();
      return;
    }

    try {
      await audioService.connectAndPublish(url: e.url, token: e.token);
      // Track is live — tell the hub immediately (satisfies the 5s rule).
      await _hub?.micActivated();
      emit(state.copyWith(handPhase: HandPhase.connecting));
      _startSpeakingEchoTimer();
    } catch (err) {
      await _endAudio();
      emit(state.copyWith(
        handPhase: HandPhase.idle,
        // A failed handshake with the media server is not the student's
        // microphone — saying so sends them hunting through their device
        // settings for an outage they can't fix.
        transientNotice: err is LiveAudioConnectException
            ? "Live audio isn't available right now. Please try again in a moment."
            : 'Could not start your microphone.',
      ));
      await _hub?.stopSpeaking();
    }
  }

  /// Promote `connecting → speaking` locally if the server echo doesn't
  /// arrive. Reaching this point means LiveKit accepted the publish and
  /// the hub accepted `MicActivated`, so the student IS on air — the echo
  /// is confirmation, not permission, and the UI must not depend on it.
  void _startSpeakingEchoTimer() {
    _speakingEchoTimer?.cancel();
    _speakingEchoTimer = Timer(_speakingEchoGrace, () {
      if (state.handPhase != HandPhase.connecting) return;
      // ignore: avoid_print
      print('[ClassHub] no nowSpeaking echo in ${_speakingEchoGrace.inSeconds}s '
          '— going live locally (myId=$myId)');
      emit(state.copyWith(
        handPhase: HandPhase.speaking,
        // Keeps self-speaking true so HLS ducking still kicks in.
        speakingStudentId: myId ?? state.speakingStudentId,
      ));
    });
  }

  /// Ends the speaking turn's audio. With [lingerToCoverEcho] the mic is
  /// released now but the room stays open for [_postSpeakLinger] so the
  /// educator remains audible in real time while the delayed HLS echo of
  /// the turn plays out muted; without it everything tears down
  /// immediately (moderation, leaving the room, or a turn that never
  /// went on air).
  Future<void> _endAudio({bool lingerToCoverEcho = false}) async {
    _speakingEchoTimer?.cancel();
    _speakingEchoTimer = null;
    _micLingerTimer?.cancel();
    _micLingerTimer = null;
    if (lingerToCoverEcho && audioService.isConnected) {
      await audioService.muteAndKeepListening();
      _micLingerTimer = Timer(_postSpeakLinger, () {
        _micLingerTimer = null;
        unawaited(audioService.disconnect());
      });
    } else {
      await audioService.disconnect();
    }
    emit(state.copyWith(handPhase: HandPhase.idle, queuePosition: null));
  }

  void clearNotice() {
    if (state.transientNotice != null) {
      emit(state.copyWith(transientNotice: null));
    }
  }

  // ── Hub event handling ───────────────────────────────────────────

  Future<void> _onHubEvent(LiveClassHubEvent event) async {
    switch (event) {
      case RoomStateEvent(:final state):
        _applyRoomState(state);
        break;

      case HubReconnectedEvent():
        // Groups don't survive reconnect; the hub already rejoined —
        // re-sync playback + chat + polls so nothing is stale.
        emit(state.copyWith(hubConnected: _hub?.isConnected ?? false));
        await _loadPlayback();
        await _loadInitialChat();
        await _loadPolls();
        break;

      case ChatMessageEvent(:final message):
        _onIncomingChat(message);
        break;

      case ChatModeChangedEvent(:final mode):
        if (mode == ChatMode.private) {
          emit(state.copyWith(
            chatMode: mode,
            messages: _applyPrivateFilter(state.messages),
          ));
        } else {
          emit(state.copyWith(chatMode: mode));
          // Reveal previously-hidden messages.
          await _loadInitialChat();
        }
        break;

      case QueuePositionEvent(:final position):
        emit(state.copyWith(
          handPhase: state.handPhase == HandPhase.idle
              ? HandPhase.queued
              : state.handPhase,
          queuePosition: position,
        ));
        break;

      case HandLoweredEvent():
        emit(state.copyWith(handPhase: HandPhase.idle, queuePosition: null));
        break;

      case MicGrantedEvent():
        await _onMicGranted(event);
        break;

      case MicExpiredEvent():
        // The turn never went on air — nothing of it is in flight on
        // HLS, so tear down immediately.
        await _endAudio();
        emit(state.copyWith(
          transientNotice: 'Mic timed out. Raise your hand again.',
        ));
        break;

      case MicReleasedEvent():
        // The educator ended the turn — same as tapping "finish": the
        // echo is still in flight.
        await _endAudio(lingerToCoverEcho: true);
        break;

      case NowSpeakingEvent(:final studentId, :final name):
        // While I'm the one connecting I hold the only outstanding grant,
        // so a nowSpeaking arriving in that window is about me even when
        // the ids can't be compared — `myId` is null (claim missing from
        // the access token) or the server omitted the id (0).
        final holdingGrant = state.handPhase == HandPhase.connecting ||
            state.handPhase == HandPhase.granted;
        final mine = (myId != null && studentId == myId) ||
            (holdingGrant && (myId == null || studentId <= 0));
        if (mine) {
          _speakingEchoTimer?.cancel();
          _speakingEchoTimer = null;
        }
        emit(state.copyWith(
          speakingStudentId: mine ? (myId ?? studentId) : studentId,
          speakingName: name,
          handPhase: mine ? HandPhase.speaking : state.handPhase,
        ));
        break;

      case SpeakerEndedEvent():
        final wasMine = isSelfSpeaking;
        emit(state.copyWith(speakingStudentId: null, speakingName: null));
        if (wasMine) await _endAudio(lingerToCoverEcho: true);
        break;

      case FlagUpdatedEvent():
        await _onFlagUpdated(event);
        break;

      case KickedEvent():
        await _endAudio();
        await _teardownHub();
        emit(state.copyWith(phase: LiveViewPhase.kicked));
        break;

      case ClassStartedEvent():
        if (state.phase == LiveViewPhase.live) {
          // The host went live AGAIN on the same room while we're still
          // rendering the old broadcast. The page only rebuilds the
          // player on a phase/URL change, and the re-minted signed URL is
          // usually byte-identical — so without this the event was
          // swallowed and the player kept buffering the dead stream.
          // Cycle through `waiting` so it is torn down and rebuilt at the
          // new live edge once segments exist.
          _livenessTimer?.cancel();
          _livenessTimer = null;
          // A restart wins over a drain in progress: drop whatever is
          // left of the tail rather than play stale audio over a live
          // class. The old controller is torn down with the phase change
          // — never resumed, which is how the tail leaked out before.
          _drainGuard?.cancel();
          _drainGuard = null;
          emit(state.copyWith(
            phase: LiveViewPhase.waiting,
            broadcastInterrupted: true,
            pauseDraining: false,
            playbackMode: PlaybackMode.video,
          ));
        }
        // Always re-resolve: the signed URL may have expired while waiting,
        // and _loadPlayback gates on the stream actually serving segments.
        // SRS needs a moment to cut the first ones after the publisher
        // connects, so going live on this event alone showed a black player.
        await _loadPlayback();
        break;

      case ClassPausedEvent():
        // The educator's broadcast stopped reaching the media server —
        // the class is NOT over. Do NOT cut to waiting: this real-time
        // signal lands in a world ~7s behind, and the host's last words
        // are still in the player buffer. Drain them first (see
        // [_beginDrain]); the waiting screen follows when the player
        // finishes. A restart inside the drain (`classStarted`) wins and
        // rebuilds the player on the new stream.
        if (state.phase == LiveViewPhase.live) _beginDrain();
        break;

      case ClassEndedEvent():
        await _endAudio();
        await _teardownHub();
        emit(state.copyWith(phase: LiveViewPhase.ended));
        break;

      case ClassCancelledEvent():
        await _endAudio();
        await _teardownHub();
        emit(state.copyWith(phase: LiveViewPhase.cancelled));
        break;

      case PollVoteAcceptedEvent(:final pollId, :final optionIds):
        _patchPoll(pollId, (p) => p.copyWith(myOptionIds: optionIds));
        break;

      case PollRevealedEvent(:final poll):
        // Counts + correct marks; own choice kept from state (the event
        // doesn't carry it).
        _upsertPoll(poll);
        break;

      case PollCancelledEvent(:final pollId):
        _patchPoll(pollId, (p) => p.copyWith(status: 'cancelled'));
        break;

      case ActionDeniedEvent(:final reason, :final pollId):
        if (reason == 'poll_not_found' && pollId != null) {
          final map = Map<int, LivePoll>.from(state.polls)..remove(pollId);
          emit(state.copyWith(polls: map));
        }
        emit(state.copyWith(transientNotice: _denyMessage(reason)));
        break;
    }
  }

  void _applyRoomState(RoomState rs) {
    // Derive my hand phase from the queue position in the snapshot.
    HandPhase hp = state.handPhase;
    if (rs.speakingStudentId != null && rs.speakingStudentId == myId) {
      hp = HandPhase.speaking;
      _speakingEchoTimer?.cancel();
      _speakingEchoTimer = null;
    } else if (rs.myQueuePosition != null) {
      hp = HandPhase.queued;
    } else if (hp == HandPhase.queued) {
      hp = HandPhase.idle;
    }
    emit(state.copyWith(
      chatMode: rs.chatMode,
      flags: rs.myFlags,
      speakingStudentId: rs.speakingStudentId,
      queuePosition: rs.myQueuePosition,
      handPhase: hp,
    ));
  }

  void _onIncomingChat(LiveChatMessage message) {
    // In private mode, hide other students' live messages.
    final hiddenByPrivate = state.chatMode == ChatMode.private &&
        !message.isEducator &&
        message.senderId != myId;
    // ignore: avoid_print
    print(
      '[ClassHub] incoming chat id=${message.id} senderId=${message.senderId} '
      'role=${message.senderRole} isEducator=${message.isEducator} '
      'mode=${state.chatMode} myId=$myId hiddenByPrivate=$hiddenByPrivate',
    );
    if (hiddenByPrivate) return;
    if (message.poll != null) _upsertPoll(message.poll!);
    // De-dupe by id ONLY when the id is real (>0). If the backend omits
    // an id (parses to 0), never treat every 0-id message as the same
    // one — that would collapse all messages into a single row.
    if (message.id > 0 && state.messages.any((m) => m.id == message.id)) {
      return;
    }
    emit(state.copyWith(messages: [message, ...state.messages]));
  }

  Future<void> _onFlagUpdated(FlagUpdatedEvent e) async {
    // Only care about events targeting me.
    if (myId == null || e.studentId != myId) return;
    final newFlags = MyFlags(
      chatBlocked: e.chatBlocked,
      micBlocked: e.micBlocked,
      handBlocked: e.handBlocked,
    );
    emit(state.copyWith(flags: newFlags));
    // If I got mic-blocked while holding the mic, drop it.
    if (e.micBlocked && (isSelfSpeaking || state.handPhase != HandPhase.idle)) {
      await _hub?.stopSpeaking();
      await _endAudio();
    }
  }

  String _denyMessage(String reason) {
    switch (reason) {
      case 'poll_closed':
        return 'Voting has closed.';
      case 'poll_already_voted':
        return 'You already answered this poll.';
      case 'poll_invalid':
        return 'Choose an option.';
      case 'poll_not_found':
        return 'This poll is no longer available.';
      case 'chat_blocked':
        return 'Chat is disabled by the host.';
      case 'hand_blocked':
        return 'Raising hand is disabled by the host.';
      case 'mic_blocked':
        return 'Audio is disabled by the host.';
      default:
        return 'That action is not allowed right now.';
    }
  }

  @override
  Future<void> close() async {
    _speakingEchoTimer?.cancel();
    _micLingerTimer?.cancel();
    _readinessTimer?.cancel();
    _livenessTimer?.cancel();
    _drainGuard?.cancel();
    await _endAudio();
    await _teardownHub();
    return super.close();
  }
}

/// Outcome of one playlist read by [LiveClassCubit._probeStreamHealth].
enum _StreamHealth {
  /// A variant is serving segments.
  alive,

  /// Reachable, but nothing is being broadcast (404/410, or playlists
  /// with no segments).
  dead,

  /// Closed out with `#EXT-X-ENDLIST`: the host stopped and the tail is
  /// still playable — drain it, then treat as dead.
  ended,

  /// Timed out / no route — says nothing about the broadcast.
  unreachable,
}
