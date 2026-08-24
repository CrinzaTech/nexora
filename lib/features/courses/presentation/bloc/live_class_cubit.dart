import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/jwt_utils.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/data/services/live_class_audio_service.dart';
import 'package:nexora/features/courses/data/services/live_class_hub_service.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_chat_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_playback_usecase.dart';
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
  final LiveClassAudioService audioService;
  final SessionService sessionService;

  LiveClassCubit({
    required this.getLiveClassPlaybackUseCase,
    required this.getStreamTokenUseCase,
    required this.getLiveClassChatUseCase,
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

  /// Polls for the stream actually going live while the student waits.
  Timer? _readinessTimer;
  static const _readinessInterval = Duration(seconds: 5);

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

    // 3) Resolve playback and backfill chat in parallel.
    await Future.wait([_loadPlayback(), _loadInitialChat()]);
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

  /// True when the playlist behind [url] is actually serving media.
  ///
  /// A master playlist only lists renditions, so follow them and look for a
  /// real segment (`#EXTINF`). SRS writes the master as soon as the class
  /// exists and leaves it there after the class ends — the variants are what
  /// come and go — so "the master fetched fine" proves nothing on its own.
  Future<bool> _isStreamReady(String url, {int depth = 0}) async {
    if (depth > 1) return false;
    final body = await _fetchPlaylist(url);
    if (body == null) return false;

    if (body.contains('#EXT-X-STREAM-INF')) {
      // Any live rendition is enough. Checking only the first would block
      // entry whenever the 720p passthrough is missing but the transcoded
      // ladder is fine — capped so a long ladder can't stall the probe.
      for (final variant in _variantUrls(url, body).take(3)) {
        if (await _isStreamReady(variant, depth: depth + 1)) return true;
      }
      return false;
    }
    return body.contains('#EXTINF');
  }

  Future<String?> _fetchPlaylist(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = res.body;
      return body.contains('#EXTM3U') ? body : null;
    } catch (_) {
      // Unreachable / timed out — not ready; the poll will retry.
      return null;
    }
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
      },
    );
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
    await _endAudio();
  }

  /// Handles a mic grant: request permission NOW, connect LiveKit, and
  /// signal the hub the instant the local track is live.
  Future<void> _onMicGranted(MicGrantedEvent e) async {
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

  Future<void> _endAudio() async {
    _speakingEchoTimer?.cancel();
    _speakingEchoTimer = null;
    await audioService.disconnect();
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
        // re-sync playback + chat so nothing is stale.
        emit(state.copyWith(hubConnected: _hub?.isConnected ?? false));
        await _loadPlayback();
        await _loadInitialChat();
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
        await _endAudio();
        emit(state.copyWith(
          transientNotice: 'Mic timed out. Raise your hand again.',
        ));
        break;

      case MicReleasedEvent():
        await _endAudio();
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
        if (wasMine) await _endAudio();
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
        // Always re-resolve: the signed URL may have expired while waiting,
        // and _loadPlayback gates on the stream actually serving segments.
        // SRS needs a moment to cut the first ones after the publisher
        // connects, so going live on this event alone showed a black player.
        await _loadPlayback();
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

      case ActionDeniedEvent(:final reason):
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
    _readinessTimer?.cancel();
    await _endAudio();
    await _teardownHub();
    return super.close();
  }
}
