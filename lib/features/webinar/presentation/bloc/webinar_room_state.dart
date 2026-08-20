part of 'webinar_room_cubit.dart';

/// What the room screen is doing right now. An explicit phase (rather
/// than a bare loading flag) is what lets the lobby say *why* the
/// learner is waiting instead of showing a spinner over nothing.
enum WebinarPhase {
  /// Taking the seat — A3 is in flight.
  joining,

  /// Seated, but the host hasn't started. Polling A4.
  lobby,

  /// `canWatch` flipped; resolving the signed HLS URL.
  connecting,

  /// Playing.
  live,

  /// Not streamed by us: a Zoom/Meet meeting to open, or a workshop
  /// with a venue to show.
  ///
  /// A phase of its own rather than a variant of the lobby, because
  /// there is nothing to wait *for* — `canWatch` never flips for either,
  /// so a lobby here would be a countdown that resolves into nothing.
  external,

  /// Finished — chat still readable, since it is a transcript.
  ended,

  cancelled,

  error,
}

/// The attendee's own position in the raise-hand → speak flow, mirrored
/// from the hub.
///
/// Declared here rather than reusing the live class's `HandPhase`: that
/// enum lives inside `live_class_cubit.dart` as a `part`, so importing it
/// would drag the whole LiveClassCubit — and its LiveKit and
/// course-completion machinery — into a feature that needs five
/// constants.
enum WebinarHandPhase {
  /// Not in the queue.
  idle,

  /// Hand raised, waiting. [WebinarRoomState.queuePosition] says where.
  queued,

  /// The host granted the mic; asking for permission and connecting.
  granted,

  /// Publishing, waiting for the server's `nowSpeaking` echo.
  connecting,

  /// Confirmed on air.
  speaking,
}

@freezed
class WebinarRoomState with _$WebinarRoomState {
  const WebinarRoomState._();

  const factory WebinarRoomState({
    @Default(WebinarPhase.joining) WebinarPhase phase,

    /// The latest A3/A4 payload. Its `message` is written to be shown
    /// verbatim in the lobby, and its `startsInSeconds` drives the
    /// countdown.
    WebinarSessionState? session,

    /// Signed and short-lived — resolved once on the `canWatch`
    /// transition, never cached across sessions.
    String? hlsUrl,

    /// Newest first, de-duplicated by id across REST and the socket.
    @Default(<LiveChatMessage>[]) List<LiveChatMessage> messages,

    /// False when the socket is down: the transcript still reads, but
    /// sending is off, and the composer says so rather than swallowing
    /// what the learner types.
    @Default(false) bool chatConnected,
    @Default(false) bool hasMoreChat,
    @Default(false) bool isLoadingMoreChat,

    /// Populated in [WebinarPhase.error].
    String? errorMessage,
    @Default(true) bool canRetry,

    /// The seat was refused because this is a paid webinar they have not
    /// bought (A3's 403). Not a dead end — the detail screen owns the
    /// checkout, so the error screen offers the way back to it.
    @Default(false) bool paymentRequired,

    /// One-shot banner (send failed, and similar).
    String? transientNotice,

    // ── Raise hand → speak ───────────────────────────────────────
    @Default(WebinarHandPhase.idle) WebinarHandPhase handPhase,

    /// Place in the queue while [WebinarHandPhase.queued]. Null until
    /// the server sends one.
    int? queuePosition,

    /// Who holds the mic right now — may be this attendee or someone
    /// else. Drives both the "X is speaking" chip and the stream duck.
    int? speakingUserId,
    String? speakingName,

    /// Per-attendee moderation, pushed by the host: chat, mic and hand
    /// can each be taken away individually.
    @Default(MyFlags()) MyFlags flags,
  }) = _WebinarRoomState;

  /// True when *this* attendee is the live speaker — the page ducks the
  /// webinar audio while it holds, so the host's voice doesn't feed back
  /// into their own open mic.
  bool isSelfSpeaking(int? myId) =>
      myId != null && speakingUserId != null && speakingUserId == myId;

  /// Somebody else has the mic.
  bool isOtherSpeaking(int? myId) =>
      speakingUserId != null && speakingUserId != myId;
}
