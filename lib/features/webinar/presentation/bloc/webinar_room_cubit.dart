import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/jwt_utils.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/data/services/live_class_audio_service.dart';
import 'package:nexora/features/courses/data/services/live_class_hub_service.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/usecases/webinar_session_usecases.dart';

part 'webinar_room_state.dart';
part 'webinar_room_cubit.freezed.dart';

/// Runs a webinar room end to end on the **account token**: take the seat
/// (A3), sit in the lobby polling state (A4), resolve playback once the
/// host goes live (A5), and carry chat over the StreamApi socket (A6/A7).
///
/// There is deliberately no registration step here. In the app the
/// learner signed up with a verified phone number — they already *are*
/// an `app_users` row — so a phone screen, a form or an OTP box would be
/// asking them to prove something the token already proves. That flow
/// belongs to the website, where the visitor is a stranger.
///
/// The socket is the same StreamApi class hub live classes use, so
/// [LiveClassHubService] is reused verbatim; only the token source
/// differs (A7 rather than the generic stream token).
class WebinarRoomCubit extends Cubit<WebinarRoomState> {
  final JoinWebinarUseCase joinWebinarUseCase;
  final GetWebinarStateUseCase getWebinarStateUseCase;
  final GetWebinarPlaybackUseCase getWebinarPlaybackUseCase;
  final GetWebinarChatUseCase getWebinarChatUseCase;
  final GetWebinarHubTokenUseCase getWebinarHubTokenUseCase;
  final SessionService sessionService;

  /// Publishes the attendee's microphone during a speaking turn.
  /// The same audio-only LiveKit wrapper the live class uses — a
  /// webinar speaking turn is the identical problem, down to keeping
  /// the stream audible while the mic is open.
  final LiveClassAudioService audioService;

  WebinarRoomCubit({
    required this.joinWebinarUseCase,
    required this.getWebinarStateUseCase,
    required this.getWebinarPlaybackUseCase,
    required this.getWebinarChatUseCase,
    required this.getWebinarHubTokenUseCase,
    required this.sessionService,
    required this.audioService,
  }) : super(const WebinarRoomState());

  /// The doc's window is 10–15 seconds; 12 sits in the middle and is what
  /// its own lobby example uses.
  static const Duration _pollInterval = Duration(seconds: 12);
  static const int _chatPageSize = 30;

  String _slug = '';
  String _roomId = '';

  /// The webinar this room belongs to. Read by the error screen, which
  /// has to be able to send a learner back to the detail page — and the
  /// checkout on it — when A3 refuses them for want of a payment.
  String get slug => _slug;
  Timer? _poll;
  LiveClassHubService? _hub;
  StreamSubscription<LiveClassHubEvent>? _hubSub;

  /// Guards the one-shot playback resolve. Without it a poll response
  /// landing while the previous one is still resolving would start a
  /// second player.
  bool _resolvingPlayback = false;

  /// Safety net for `connecting → speaking`. By the time it starts the
  /// mic is published and `MicActivated` acknowledged, so the attendee
  /// **is** on air; the server's echo is confirmation, not permission.
  /// Without this a missing echo would leave them on "Connecting…" while
  /// the room can already hear them.
  Timer? _speakingEchoTimer;
  static const Duration _speakingEchoGrace = Duration(seconds: 4);

  /// This learner's own `app_users.id`, decoded from the access token, so
  /// their own chat bubbles align right. `senderId` on the wire is the
  /// same id.
  int? get myId => JwtUtils.currentUserId(sessionService.token);

  // ── Entry ────────────────────────────────────────────────────────

  /// Take the seat and enter. [roomId] comes from the A1/A2 payload and
  /// is only ever used to join the socket room.
  Future<void> enter({required String slug, required String roomId}) async {
    _slug = slug;
    _roomId = roomId;
    emit(state.copyWith(phase: WebinarPhase.joining));

    // A3 both seats them and hands back the lobby payload, so there is
    // no follow-up state call on the way in.
    final result = await joinWebinarUseCase(slug);
    if (isClosed) return;

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      _emitFailure(failure);
      return;
    }

    await _applySessionState(result.fold((_) => null, (s) => s)!);

    // Chat is a transcript and works before, during and after the class,
    // so it is wired up regardless of which *phase* we landed in — but
    // only for a webinar we actually stream. A meeting or a workshop has
    // no chat at all: A6 answers with an empty list and A7 refuses with
    // a 409, so opening a socket for one collects errors and shows an
    // empty panel where the conversation is happening in Zoom, or in
    // the room.
    if (state.session?.isStream ?? false) unawaited(_startChat());
  }

  /// Retry after a hard error.
  Future<void> retry() => enter(slug: _slug, roomId: _roomId);

  // ── Lobby ────────────────────────────────────────────────────────

  /// Picks the screen. `canWatch` decides whether to *play*; `joinMode`
  /// decides whether there is anything to play at all.
  ///
  /// **`canWatch` is always false for a meeting and for a workshop.**
  /// Reading it first — `if (!canWatch) showLobby()` — is the trap the
  /// API doc calls out by name: it leaves a Zoom or in-person attendee
  /// watching a countdown that never resolves into anything.
  Future<void> _applySessionState(WebinarSessionState session) async {
    emit(state.copyWith(session: session));

    // Kept ahead of everything else: `canWatch` is computed against the
    // clock, while `status` is a cached column that can sit stale at
    // "Ended" long after — or before — it is true.
    if (session.canWatch) {
      _stopPolling();
      await _resolvePlayback();
      return;
    }

    if (session.hasEnded) {
      _stopPolling();
      emit(
        state.copyWith(
          phase: session.isCancelled
              ? WebinarPhase.cancelled
              : WebinarPhase.ended,
        ),
      );
      return;
    }

    if (!session.isStream) {
      // Nothing to poll *for*: the meeting link and the venue are both
      // released the moment they are registered, and neither ever turns
      // into a stream. Render from this one response and stop.
      _stopPolling();
      emit(state.copyWith(phase: WebinarPhase.external));
      return;
    }

    emit(state.copyWith(phase: WebinarPhase.lobby));
    _startPolling();
  }

  void _startPolling() {
    if (_poll != null) return;
    _poll = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollOnce() async {
    if (isClosed || state.phase != WebinarPhase.lobby) return;
    final result = await getWebinarStateUseCase(_slug);
    if (isClosed) return;

    result.fold((failure) {
      // A 403 mid-lobby means the host closed the link or the seat was
      // removed — that is terminal and worth surfacing. Anything else
      // is a blip: keep the lobby up and let the next tick retry.
      if (_statusOf(failure) == 403) {
        _stopPolling();
        _emitFailure(failure);
      }
    }, (session) => _applySessionState(session));
  }

  // ── Playback ─────────────────────────────────────────────────────

  /// Called **once** on the `canWatch` transition, never on a timer. The
  /// stream serves media only while the room is live; polling it before
  /// that just collects 409s.
  Future<void> _resolvePlayback() async {
    if (_resolvingPlayback) return;
    // A5 answers 409 for a meeting or a workshop. The doc's advice is to
    // not call it at all rather than read the message back out of the
    // error, so this is the one guard rather than a catch below.
    if (!(state.session?.isStream ?? true)) return;
    _resolvingPlayback = true;
    emit(state.copyWith(phase: WebinarPhase.connecting));

    final result = await getWebinarPlaybackUseCase(_slug);
    _resolvingPlayback = false;
    if (isClosed) return;

    result.fold(
      (failure) {
        switch (_statusOf(failure)) {
          case 409:
            // "Not started yet" — the state call and the stream disagree
            // for a moment around the transition. Back to the lobby.
            emit(state.copyWith(phase: WebinarPhase.lobby));
            _startPolling();
          case 410:
            _stopPolling();
            emit(state.copyWith(phase: WebinarPhase.ended));
          default:
            _emitFailure(failure);
        }
      },
      (hlsUrl) {
        _stopPolling();
        emit(state.copyWith(phase: WebinarPhase.live, hlsUrl: hlsUrl));
      },
    );
  }

  /// Re-resolve a fresh signed URL — the player asks for this when its
  /// link expires mid-session, or after a long background.
  Future<void> refreshPlayback() async {
    if (state.phase == WebinarPhase.ended ||
        state.phase == WebinarPhase.cancelled ||
        state.phase == WebinarPhase.external) {
      return;
    }
    await _resolvePlayback();
  }

  // ── Chat ─────────────────────────────────────────────────────────

  Future<void> _startChat() async {
    await _loadInitialChat();
    await _connectHub();
  }

  Future<void> _loadInitialChat() async {
    final result = await getWebinarChatUseCase(_slug, limit: _chatPageSize);
    if (isClosed) return;
    result.fold(
      // Chat failing is not the class failing — the lesson still plays.
      (_) {},
      (messages) => emit(
        state.copyWith(
          messages: _merge(state.messages, messages),
          hasMoreChat: messages.length >= _chatPageSize,
        ),
      ),
    );
  }

  /// Pages backwards from the oldest message currently held.
  Future<void> loadMoreChat() async {
    if (state.isLoadingMoreChat || !state.hasMoreChat) return;
    final oldest = state.messages.isEmpty ? null : state.messages.last.id;
    if (oldest == null) return;

    emit(state.copyWith(isLoadingMoreChat: true));
    final result = await getWebinarChatUseCase(
      _slug,
      beforeId: oldest,
      limit: _chatPageSize,
    );
    if (isClosed) return;

    result.fold(
      (_) => emit(state.copyWith(isLoadingMoreChat: false)),
      (older) => emit(
        state.copyWith(
          messages: _merge(state.messages, older),
          hasMoreChat: older.length >= _chatPageSize,
          isLoadingMoreChat: false,
        ),
      ),
    );
  }

  Future<void> _connectHub() async {
    // Minted per connection attempt, never cached: it is short-lived
    // enough that one fetched at entry is dead by the time a reconnect
    // needs it.
    final tokenResult = await getWebinarHubTokenUseCase(_slug);
    if (isClosed) return;
    final token = tokenResult.fold((_) => null, (t) => t);
    if (token == null) {
      emit(state.copyWith(chatConnected: false));
      return;
    }

    await _teardownHub();
    final hub = LiveClassHubService(accessToken: token);
    _hub = hub;
    _hubSub = hub.events.listen(_onHubEvent);
    try {
      await hub.connect(_roomId, accessToken: token);
      if (isClosed) return;
      emit(state.copyWith(chatConnected: hub.isConnected));
    } catch (_) {
      if (isClosed) return;
      // The transcript still loaded over REST, so say chat is read-only
      // rather than pretending the socket is fine and silently dropping
      // every message the learner types.
      emit(state.copyWith(chatConnected: false));
    }
  }

  void _onHubEvent(LiveClassHubEvent event) {
    if (isClosed) return;
    switch (event) {
      case ChatMessageEvent(:final message):
        emit(state.copyWith(messages: _merge(state.messages, [message])));
      case ClassStartedEvent():
        // The host went live; skip the wait for the next poll tick.
        if (state.phase == WebinarPhase.lobby) unawaited(_resolvePlayback());
      case ClassEndedEvent():
        _stopPolling();
        emit(state.copyWith(phase: WebinarPhase.ended));
      case ClassCancelledEvent():
        _stopPolling();
        emit(state.copyWith(phase: WebinarPhase.cancelled));
      case HubReconnectedEvent():
        // Groups don't survive a reconnect and messages sent during the
        // gap never arrived — refill from REST and de-dupe by id.
        emit(state.copyWith(chatConnected: _hub?.isConnected ?? false));
        unawaited(_loadInitialChat());

      // ── Raise hand → speak ─────────────────────────────────────
      // Bound as `roomState` because the field is named `state`, which
      // would shadow the cubit's own.
      case RoomStateEvent(state: final roomState):
        // Sent on join and after a reconnect: the authoritative picture
        // of who is speaking, where this attendee sits in the queue, and
        // what the host currently allows them to do. This is what makes
        // a reconnect land in the right place instead of resetting the
        // hand to idle.
        emit(
          state.copyWith(
            flags: roomState.myFlags,
            speakingUserId: roomState.speakingStudentId,
            queuePosition: roomState.myQueuePosition,
            handPhase: _phaseFromRoomState(roomState),
          ),
        );

      case QueuePositionEvent(:final position):
        // Confirms the optimistic `queued` from [raiseHand], and moves
        // as the queue drains.
        emit(
          state.copyWith(
            handPhase: WebinarHandPhase.queued,
            queuePosition: position,
          ),
        );

      case HandLoweredEvent():
        // The host dismissed the hand. Silent — a notice for something
        // the attendee can simply raise again is noise.
        emit(
          state.copyWith(handPhase: WebinarHandPhase.idle, queuePosition: null),
        );

      case MicGrantedEvent():
        unawaited(_onMicGranted(event));

      case MicExpiredEvent():
        // The grant window elapsed before the mic went live.
        unawaited(_endSpeaking());
        emit(state.copyWith(transientNotice: 'Your turn to speak timed out.'));

      case MicReleasedEvent():
        // The host ended the turn, or moderation changed while it was
        // held. Tear the mic down rather than leaving it publishing to a
        // room that has stopped listening.
        unawaited(_endSpeaking());

      case NowSpeakingEvent(:final studentId, :final name):
        _speakingEchoTimer?.cancel();
        _speakingEchoTimer = null;
        emit(
          state.copyWith(
            speakingUserId: studentId,
            speakingName: name,
            // Only promote *this* attendee — the same event announces
            // other people taking the mic.
            handPhase: studentId == myId
                ? WebinarHandPhase.speaking
                : state.handPhase,
          ),
        );

      case SpeakerEndedEvent():
        final wasMine = state.isSelfSpeaking(myId);
        emit(state.copyWith(speakingUserId: null, speakingName: null));
        if (wasMine) unawaited(_endSpeaking());

      case FlagUpdatedEvent(
        :final studentId,
        :final chatBlocked,
        :final micBlocked,
        :final handBlocked,
      ):
        // The hub broadcasts flag changes for everyone in the room; only
        // this attendee's own flags belong in this state.
        if (studentId != myId) break;
        emit(
          state.copyWith(
            flags: MyFlags(
              chatBlocked: chatBlocked,
              micBlocked: micBlocked,
              handBlocked: handBlocked,
            ),
          ),
        );
        // Losing the mic mid-turn ends it — the server has already
        // stopped carrying the audio.
        if (micBlocked && state.handPhase != WebinarHandPhase.idle) {
          unawaited(_endSpeaking());
        }

      case ActionDeniedEvent(:final reason):
        emit(state.copyWith(transientNotice: _denialMessage(reason)));

      case KickedEvent(:final reason):
        unawaited(_endSpeaking());
        _stopPolling();
        emit(
          state.copyWith(
            phase: WebinarPhase.error,
            canRetry: false,
            errorMessage: reason.isEmpty
                ? 'The host removed you from this webinar.'
                : reason,
          ),
        );

      default:
        break;
    }
  }

  /// Reconciles the local hand phase with a fresh `roomState`.
  ///
  /// Only used on join/reconnect, and deliberately conservative: it can
  /// restore "queued" and "speaking", which the server knows about, but
  /// never invents the transient `granted`/`connecting` states, which
  /// only exist locally between the grant and the mic going live.
  WebinarHandPhase _phaseFromRoomState(RoomState roomState) {
    if (roomState.speakingStudentId != null &&
        roomState.speakingStudentId == myId) {
      return WebinarHandPhase.speaking;
    }
    if (roomState.myQueuePosition != null) return WebinarHandPhase.queued;
    // Mid-handshake: a roomState arriving while the mic is coming up
    // must not knock the attendee back to idle.
    if (state.handPhase == WebinarHandPhase.granted ||
        state.handPhase == WebinarHandPhase.connecting) {
      return state.handPhase;
    }
    return WebinarHandPhase.idle;
  }

  /// The hub's denial reasons are machine tokens (`chat_blocked`,
  /// `hand_blocked`, `mic_blocked`); turn them into something an
  /// attendee can act on rather than showing the raw string.
  String _denialMessage(String reason) {
    switch (reason.trim().toLowerCase()) {
      case 'chat_blocked':
        return 'The host has turned off chat for you.';
      case 'hand_blocked':
        return 'The host has turned off raising hands for you.';
      case 'mic_blocked':
        return 'The host has turned off your microphone.';
      default:
        return "That didn't go through.";
    }
  }

  Future<void> sendChat(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    try {
      await _hub?.sendChat(text);
    } catch (_) {
      emit(
        state.copyWith(
          transientNotice: "Couldn't send that message. Try again.",
        ),
      );
    }
  }

  // ── Raise hand → speak ───────────────────────────────────────────
  //
  // The webinar hub is the same StreamApi class hub the live class uses,
  // reached with the token A7/B7 mints and joined with the same
  // `JoinRoom(roomId)`. The whole raise-hand exchange — RaiseHand,
  // queuePosition, micGranted, MicActivated, nowSpeaking, StopSpeaking —
  // is therefore already available to a webinar attendee; only the token
  // source differs. The host drives it from the same admin console.

  /// Ask for the mic. Optimistic: the queue position arrives separately,
  /// and the button should not sit dead waiting for it.
  Future<void> raiseHand() async {
    if (state.flags.handBlocked) return;
    if (!(_hub?.isConnected ?? false)) {
      emit(
        state.copyWith(
          chatConnected: false,
          transientNotice:
              'Not connected to the webinar — try again in a moment.',
        ),
      );
      return;
    }
    try {
      await _hub?.raiseHand();
      emit(state.copyWith(handPhase: WebinarHandPhase.queued));
    } catch (_) {
      emit(state.copyWith(transientNotice: "Couldn't raise your hand."));
    }
  }

  Future<void> lowerHand() async {
    try {
      await _hub?.lowerHand();
    } catch (_) {
      // Lowering is a courtesy to the queue; if the socket dropped, the
      // server drops the hand with the connection anyway.
    }
    emit(state.copyWith(handPhase: WebinarHandPhase.idle, queuePosition: null));
  }

  /// "I'm done" — hands the mic back so the queue moves on.
  Future<void> stopSpeaking() async {
    try {
      await _hub?.stopSpeaking();
    } catch (_) {}
    await _endSpeaking();
  }

  /// The host granted the mic. Permission is requested **now**, not at
  /// entry: asking a webinar audience for a microphone the moment they
  /// arrive is a prompt almost none of them need, and one they will
  /// mostly deny — which would then block the few who do want to speak.
  Future<void> _onMicGranted(MicGrantedEvent event) async {
    if (state.flags.micBlocked) return;
    emit(state.copyWith(handPhase: WebinarHandPhase.granted));

    final status = await Permission.microphone.request();
    if (isClosed) return;
    if (!status.isGranted) {
      emit(
        state.copyWith(
          handPhase: WebinarHandPhase.idle,
          transientNotice: 'Microphone permission is needed to speak.',
        ),
      );
      // Give the turn back so the host isn't left waiting on someone who
      // cannot take it.
      await _hub?.stopSpeaking();
      return;
    }

    try {
      await audioService.connectAndPublish(url: event.url, token: event.token);
      if (isClosed) return;
      // The grant expires in seconds — tell the hub the instant the
      // track is live rather than after any UI settles.
      await _hub?.micActivated();
      emit(state.copyWith(handPhase: WebinarHandPhase.connecting));
      _startSpeakingEchoTimer();
    } catch (e) {
      await _endSpeaking();
      if (isClosed) return;
      emit(
        state.copyWith(
          handPhase: WebinarHandPhase.idle,
          // A failed handshake with the media server is not the
          // attendee's microphone. Saying "check your mic" would send
          // them through their device settings hunting for an outage
          // they cannot fix.
          transientNotice: e is LiveAudioConnectException
              ? "Live audio isn't available right now. Please try again "
                    'in a moment.'
              : 'Could not start your microphone.',
        ),
      );
      await _hub?.stopSpeaking();
    }
  }

  void _startSpeakingEchoTimer() {
    _speakingEchoTimer?.cancel();
    _speakingEchoTimer = Timer(_speakingEchoGrace, () {
      if (isClosed || state.handPhase != WebinarHandPhase.connecting) return;
      emit(
        state.copyWith(
          handPhase: WebinarHandPhase.speaking,
          // Keeps `isSelfSpeaking` true so the stream still ducks.
          speakingUserId: myId ?? state.speakingUserId,
        ),
      );
    });
  }

  Future<void> _endSpeaking() async {
    _speakingEchoTimer?.cancel();
    _speakingEchoTimer = null;
    await audioService.disconnect();
    if (isClosed) return;
    emit(state.copyWith(handPhase: WebinarHandPhase.idle, queuePosition: null));
  }

  void clearNotice() => emit(state.copyWith(transientNotice: null));

  /// Newest-first, de-duplicated by id — the socket push and the REST
  /// backfill deliver the same message, and `senderId` arrives as a
  /// string over the socket and a number over REST (already normalised
  /// by [LiveChatMessage.fromJson]).
  List<LiveChatMessage> _merge(
    List<LiveChatMessage> existing,
    List<LiveChatMessage> incoming,
  ) {
    final byId = {for (final m in existing) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    return merged;
  }

  // ── Failure mapping ──────────────────────────────────────────────

  void _emitFailure(Failure failure) {
    final status = _statusOf(failure);
    switch (status) {
      case 403:
        // "This webinar requires payment…" is not the same 403 as "the
        // host closed the link": one has a way forward and the other
        // doesn't. The checkout lives on the detail screen, so this is
        // flagged for the error view to offer the way back to it.
        emit(
          state.copyWith(
            phase: WebinarPhase.error,
            errorMessage: failure.message,
            canRetry: false,
            paymentRequired: _mentionsPayment(failure.message),
          ),
        );
      case 404:
        emit(
          state.copyWith(
            phase: WebinarPhase.error,
            errorMessage: 'This webinar is no longer available.',
            canRetry: false,
          ),
        );
      case 410:
        emit(state.copyWith(phase: WebinarPhase.ended));
      case 503:
        emit(
          state.copyWith(
            phase: WebinarPhase.error,
            errorMessage: 'Streaming is temporarily unavailable.',
            canRetry: true,
          ),
        );
      default:
        emit(
          state.copyWith(
            phase: WebinarPhase.error,
            errorMessage: failure.message,
            canRetry: true,
          ),
        );
    }
  }

  /// The 403 that means "buy it first" rather than "you may not come in".
  bool _mentionsPayment(String message) =>
      message.toLowerCase().contains('payment');

  int? _statusOf(Failure failure) => failure.maybeWhen(
    server: (_, statusCode) => statusCode,
    orElse: () => null,
  );

  Future<void> _teardownHub() async {
    await _hubSub?.cancel();
    _hubSub = null;
    await _hub?.dispose();
    _hub = null;
  }

  @override
  Future<void> close() async {
    _stopPolling();
    _speakingEchoTimer?.cancel();
    // Releases the microphone and restores the OS audio session. Leaving
    // this out would keep publishing after the attendee left the page.
    await audioService.disconnect();
    await _teardownHub();
    return super.close();
  }
}
