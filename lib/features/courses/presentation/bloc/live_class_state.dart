part of 'live_class_cubit.dart';

/// Top-level view phase — never a bare spinner (§3). The UI switches its
/// whole body on this.
enum LiveViewPhase {
  /// Bootstrapping: token + playback + hub connect in flight.
  loading,

  /// Class scheduled/ready but not started — friendly waiting label,
  /// auto-joins on `classStarted`.
  waiting,

  /// Playing: player + chat + hand-raise UI.
  live,

  /// Session finished.
  ended,

  /// Class was cancelled or deleted.
  cancelled,

  /// The host removed this student.
  kicked,

  /// A hard error (not-enrolled / not-found / service-down / network).
  error,
}

/// Which media pipeline is active. Video is the default; the app falls
/// back to audio-only automatically on weak network / background, and
/// recovers to video automatically when the connection allows.
enum PlaybackMode {
  video,
  switchingToAudio,
  audio,
  switchingToVideo,
}

/// The student's own raise-hand → speak position, mirrored from server.
enum HandPhase {
  /// Not in the queue.
  idle,

  /// Hand raised, waiting in the queue.
  queued,

  /// Mic granted; acquiring permission + connecting LiveKit.
  granted,

  /// LiveKit connected, mic published, waiting for `nowSpeaking` echo.
  connecting,

  /// Confirmed live speaker.
  speaking,
}

@freezed
class LiveClassState with _$LiveClassState {
  const LiveClassState._();

  const factory LiveClassState({
    @Default(LiveViewPhase.loading) LiveViewPhase phase,

    /// Resolved signed HLS URL (null until live).
    String? hlsUrl,

    /// Audio-only rendition URL for weak-network / background fallback.
    String? audioUrl,

    /// Active media pipeline (video ↔ audio-only). The UI renders the
    /// player, switching indicator, or audio panel from this.
    @Default(PlaybackMode.video) PlaybackMode playbackMode,

    /// Populated in the [LiveViewPhase.error] phase.
    String? errorMessage,
    @Default(false) bool canRetry,

    /// Scheduled start, drives the optional countdown in the waiting UI.
    DateTime? scheduledAt,

    /// Whether the SignalR class hub is connected. When false, chat send
    /// / raise-hand can't reach the server — the UI reflects this instead
    /// of silently doing nothing.
    @Default(false) bool hubConnected,

    // ── Chat ──────────────────────────────────────────────────────
    @Default(ChatMode.shared) ChatMode chatMode,
    @Default(<LiveChatMessage>[]) List<LiveChatMessage> messages,
    @Default(false) bool chatLoadingMore,
    @Default(true) bool chatHasMore,

    // ── Moderation flags (self) ──────────────────────────────────
    @Default(MyFlags()) MyFlags flags,

    // ── Hand-raise / speak ───────────────────────────────────────
    @Default(HandPhase.idle) HandPhase handPhase,
    int? queuePosition,

    /// Who currently holds the mic (may be me or another student).
    int? speakingStudentId,
    String? speakingName,

    /// Ephemeral one-shot notice (e.g. "Mic timed out"). The UI shows it
    /// then the cubit clears it via [clearNotice].
    String? transientNotice,
  }) = _LiveClassState;

  /// True when I am the confirmed live speaker — the page ducks the HLS
  /// volume while this holds.
  bool isSelfSpeaking(int? myId) =>
      myId != null && speakingStudentId != null && speakingStudentId == myId;

  /// Another student (not me) is speaking.
  bool isOtherSpeaking(int? myId) =>
      speakingStudentId != null && speakingStudentId != myId;
}
