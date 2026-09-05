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

  /// `text` (default) or `poll`. Render by kind; an old server sends no
  /// kind at all and every message is text.
  final String kind;
  final int? pollId;

  /// The poll as shaped for this viewer, carried on the row itself. The
  /// cubit keeps the live copy in its poll map; this is the seed.
  final LivePoll? poll;

  const LiveChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.kind = 'text',
    this.pollId,
    this.poll,
  });

  bool get isPoll => kind.toLowerCase() == 'poll' || poll != null;

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
      kind: readStr(['kind', 'Kind']) ?? 'text',
      pollId: readNum(['pollId', 'PollId'])?.toInt(),
      poll: (json['poll'] ?? json['Poll']) is Map
          ? LivePoll.fromJson(
              Map<String, dynamic>.from((json['poll'] ?? json['Poll']) as Map),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Polls / choice questions posted into the chat by the educator.
// ─────────────────────────────────────────────────────────────────────

dynamic _pick(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    if (json.containsKey(k) && json[k] != null) return json[k];
    // The API is not consistent about casing across paths.
    final cap = k[0].toUpperCase() + k.substring(1);
    if (json.containsKey(cap) && json[cap] != null) return json[cap];
  }
  return null;
}

int? _pickInt(Map<String, dynamic> json, List<String> keys) {
  final v = _pick(json, keys);
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? _pickBool(Map<String, dynamic> json, List<String> keys) {
  final v = _pick(json, keys);
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

class LivePollOption {
  final int id;
  final int position;
  final String label;

  /// Set only once results are visible AND the poll has a correct answer.
  final bool? isCorrect;

  /// Set only once results are visible to this viewer.
  final int? votes;

  const LivePollOption({
    required this.id,
    required this.position,
    required this.label,
    this.isCorrect,
    this.votes,
  });

  factory LivePollOption.fromJson(Map<String, dynamic> json) {
    return LivePollOption(
      id: _pickInt(json, ['id', 'optionId']) ?? 0,
      position: _pickInt(json, ['position', 'order']) ?? 0,
      label: _pick(json, ['label', 'text'])?.toString() ?? '',
      isCorrect: _pickBool(json, ['isCorrect']),
      votes: _pickInt(json, ['votes', 'count']),
    );
  }
}

/// A poll as shaped for THIS viewer: students only get counts and correct
/// marks once results are visible; `myOptionIds` is their own answer.
class LivePoll {
  final int id;
  final String roomId;
  final String question;

  /// `single` (pick exactly one) or `multiple` (any number).
  final String pollType;

  /// `timed` (results public at [revealAt]) or `manual` (when the host
  /// shares them).
  final String revealMode;
  final int? revealAfterMin;

  /// Countdown target for timed polls; voting closes at the same moment.
  final DateTime? revealAt;

  /// `open` | `revealed` | `cancelled`.
  final String status;
  final DateTime? createdAt;
  final DateTime? revealedAt;
  final bool hasCorrectAnswer;

  /// Whether this viewer may see counts (students: only after reveal).
  final bool resultsVisible;

  /// Distinct students who answered — null until [resultsVisible].
  final int? attempted;

  /// This student's own choice(s); empty = not answered yet.
  final List<int> myOptionIds;
  final List<LivePollOption> options;

  const LivePoll({
    required this.id,
    required this.roomId,
    required this.question,
    required this.pollType,
    required this.revealMode,
    this.revealAfterMin,
    this.revealAt,
    required this.status,
    this.createdAt,
    this.revealedAt,
    this.hasCorrectAnswer = false,
    this.resultsVisible = false,
    this.attempted,
    this.myOptionIds = const [],
    this.options = const [],
  });

  bool get isMultiple => pollType.toLowerCase() == 'multiple';
  bool get isTimed => revealMode.toLowerCase() == 'timed';
  bool get isRevealed => status.toLowerCase() == 'revealed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isOpen => status.toLowerCase() == 'open';
  bool get hasAnswered => myOptionIds.isNotEmpty;

  /// A timed poll whose deadline passed but whose `pollRevealed` hasn't
  /// reached us yet (hub hiccup) — voting is closed server-side anyway.
  bool get deadlinePassed {
    final at = revealAt;
    return at != null && !DateTime.now().isBefore(at);
  }

  bool get canVote => isOpen && !hasAnswered && !deadlinePassed;

  LivePoll copyWith({String? status, List<int>? myOptionIds}) {
    return LivePoll(
      id: id,
      roomId: roomId,
      question: question,
      pollType: pollType,
      revealMode: revealMode,
      revealAfterMin: revealAfterMin,
      revealAt: revealAt,
      status: status ?? this.status,
      createdAt: createdAt,
      revealedAt: revealedAt,
      hasCorrectAnswer: hasCorrectAnswer,
      resultsVisible: resultsVisible,
      attempted: attempted,
      myOptionIds: myOptionIds ?? this.myOptionIds,
      options: options,
    );
  }

  factory LivePoll.fromJson(Map<String, dynamic> json) {
    DateTime? date(List<String> keys) {
      final raw = _pick(json, keys);
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    final rawOptions = _pick(json, ['options']);
    final options = <LivePollOption>[];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        if (o is Map) {
          options.add(LivePollOption.fromJson(Map<String, dynamic>.from(o)));
        }
      }
      options.sort((a, b) => a.position.compareTo(b.position));
    }
    final rawMine = _pick(json, ['myOptionIds']);
    final mine = <int>[];
    if (rawMine is List) {
      for (final v in rawMine) {
        final n = v is num ? v.toInt() : int.tryParse(v.toString());
        if (n != null) mine.add(n);
      }
    }
    return LivePoll(
      id: _pickInt(json, ['id', 'pollId']) ?? 0,
      roomId: _pick(json, ['roomId'])?.toString() ?? '',
      question: _pick(json, ['question', 'body'])?.toString() ?? '',
      pollType: _pick(json, ['pollType', 'type'])?.toString() ?? 'single',
      revealMode: _pick(json, ['revealMode'])?.toString() ?? 'manual',
      revealAfterMin: _pickInt(json, ['revealAfterMin']),
      revealAt: date(['revealAt']),
      status: _pick(json, ['status'])?.toString() ?? 'open',
      createdAt: date(['createdAt']),
      revealedAt: date(['revealedAt']),
      hasCorrectAnswer: _pickBool(json, ['hasCorrectAnswer']) ?? false,
      resultsVisible: _pickBool(json, ['resultsVisible']) ?? false,
      attempted: _pickInt(json, ['attempted']),
      myOptionIds: mine,
      options: options,
    );
  }
}
