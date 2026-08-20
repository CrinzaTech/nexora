// Data models + enums for the live-class real-time layer (SignalR
// `/hubs/class`). Kept independent of the HLS playback models so the
// realtime feature can evolve without touching curriculum parsing.

/// Result of the playback endpoint: the adaptive master HLS URL plus an
/// audio-only rendition used for weak-network / background fallback.
class LivePlayback {
  /// Adaptive master playlist (video).
  final String hlsUrl;

  /// Audio-only child playlist. Prefer the server-provided `audioUrl`;
  /// falls back to deriving it from [hlsUrl] when the field is absent.
  final String audioUrl;

  const LivePlayback({required this.hlsUrl, required this.audioUrl});

  /// Builds a [LivePlayback] from the proxy's `data` object. Reads an
  /// explicit `audioUrl` when present (recommended server contract);
  /// otherwise derives the audio child from the master filename:
  ///   …/{key}/master_{key}.m3u8  →  …/{key}/{key}_audio.m3u8
  factory LivePlayback.fromData(String hlsUrl, {String? audioUrl}) {
    final audio = (audioUrl != null && audioUrl.isNotEmpty)
        ? audioUrl
        : _deriveAudioUrl(hlsUrl);
    return LivePlayback(hlsUrl: hlsUrl, audioUrl: audio);
  }

  /// Swaps the master filename segment for the audio child under the
  /// same signed path. Handles the documented `master_{key}.m3u8` shape
  /// and degrades to a generic `*.m3u8 → *_audio.m3u8` swap; returns the
  /// master URL unchanged if it can't recognise the pattern (caller then
  /// simply has no audio fallback).
  static String _deriveAudioUrl(String master) {
    final uri = Uri.tryParse(master);
    if (uri == null) return master;
    final segments = [...uri.pathSegments];
    if (segments.isEmpty) return master;
    final file = segments.last;
    if (!file.endsWith('.m3u8')) return master;

    String audioFile;
    final masterMatch = RegExp(r'^master_(.+)\.m3u8$').firstMatch(file);
    if (masterMatch != null) {
      audioFile = '${masterMatch.group(1)}_audio.m3u8';
    } else {
      audioFile = '${file.substring(0, file.length - '.m3u8'.length)}_audio.m3u8';
    }
    segments[segments.length - 1] = audioFile;
    return uri.replace(pathSegments: segments).toString();
  }
}

/// Chat visibility mode, controlled by the educator.
enum ChatMode {
  /// Everyone sees everyone's messages.
  shared,

  /// Students see only the educator's messages and their own.
  private;

  static ChatMode fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'private':
        return ChatMode.private;
      case 'shared':
      default:
        return ChatMode.shared;
    }
  }
}

/// The student's own moderation flags, mirrored from the server.
class MyFlags {
  final bool chatBlocked;
  final bool micBlocked;
  final bool handBlocked;

  const MyFlags({
    this.chatBlocked = false,
    this.micBlocked = false,
    this.handBlocked = false,
  });

  MyFlags copyWith({bool? chatBlocked, bool? micBlocked, bool? handBlocked}) {
    return MyFlags(
      chatBlocked: chatBlocked ?? this.chatBlocked,
      micBlocked: micBlocked ?? this.micBlocked,
      handBlocked: handBlocked ?? this.handBlocked,
    );
  }

  factory MyFlags.fromJson(Map<String, dynamic> json) {
    return MyFlags(
      chatBlocked: json['chatBlocked'] as bool? ?? false,
      micBlocked: json['micBlocked'] as bool? ?? false,
      handBlocked: json['handBlocked'] as bool? ?? false,
    );
  }
}

/// Initial snapshot pushed as the hub `roomState` event right after
/// `JoinRoom`, and re-fetched after an automatic reconnect.
class RoomState {
  final ChatMode chatMode;
  final MyFlags myFlags;

  /// `app_user.id` of the student currently holding the mic, or null
  /// when nobody is speaking.
  final int? speakingStudentId;

  /// The caller's own place in the hand-raise queue, or null when their
  /// hand isn't raised.
  final int? myQueuePosition;

  const RoomState({
    this.chatMode = ChatMode.shared,
    this.myFlags = const MyFlags(),
    this.speakingStudentId,
    this.myQueuePosition,
  });

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final flagsRaw = json['myFlags'];
    return RoomState(
      chatMode: ChatMode.fromString(json['chatMode']?.toString()),
      myFlags: flagsRaw is Map
          ? MyFlags.fromJson(Map<String, dynamic>.from(flagsRaw))
          : const MyFlags(),
      speakingStudentId: (json['speakingStudentId'] as num?)?.toInt(),
      myQueuePosition: (json['myQueuePosition'] as num?)?.toInt(),
    );
  }
}

/// One chat message, from either hub `chatMessage` push or the REST
/// backfill (`GET .../chat`). Both wire shapes share these fields.
class LiveChatMessage {
  final int id;
  final int senderId;

  /// `'educator'` or `'student'` — drives private-mode filtering and
  /// bubble styling.
  final String senderRole;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const LiveChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  /// True for any non-student sender. The backend role for the teacher
  /// may be spelled `educator`, `teacher`, `host`, `instructor`,
  /// `tutor`, `mentor`, or `admin` — we treat anything that isn't an
  /// explicit `student` as the educator so their messages are never
  /// mis-filtered in private mode.
  bool get isEducator {
    final role = senderRole.toLowerCase().trim();
    if (role.isEmpty) return false;
    return role != 'student' && role != 'learner';
  }

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    // Tolerant of the backend's exact field spelling — the same message
    // shape ships from both the REST history and the hub push, and the
    // wire keys weren't verifiable up front. Read the first present
    // alias for each field.
    num? readNum(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v;
        if (v is String) {
          final p = num.tryParse(v);
          if (p != null) return p;
        }
      }
      return null;
    }

    String? readStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    final createdRaw = readStr(
      ['createdAt', 'created_at', 'timestamp', 'sentAt', 'createdOn', 'time'],
    );
    return LiveChatMessage(
      id: readNum(['id', 'messageId', 'chatMessageId', 'chatId', 'msgId'])
              ?.toInt() ??
          0,
      senderId:
          readNum(['senderId', 'userId', 'appUserId', 'studentId', 'fromId'])
              ?.toInt() ??
          0,
      senderRole:
          readStr(['senderRole', 'role', 'userRole', 'senderType']) ?? 'student',
      senderName: readStr([
            'senderName',
            'name',
            'userName',
            'senderFullName',
            'fullName',
          ]) ??
          '',
      body: readStr(['body', 'message', 'text', 'content', 'msg']) ?? '',
      createdAt: (createdRaw != null
              ? DateTime.tryParse(createdRaw)?.toLocal()
              : null) ??
          DateTime.now(),
    );
  }
}
