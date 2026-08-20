import 'package:nexora/core/constants/chat_limits.dart';

/// Sender role on a [ChatMessage]. Backend ships these as strings; we
/// collapse unknown values to [other] so a future "Admin" / "System" /
/// "Bot" addition doesn't crash the parser.
enum ChatSenderType {
  student,
  educator,
  other;

  static ChatSenderType fromWire(Object? raw) {
    if (raw is! String) return ChatSenderType.other;
    switch (raw.trim().toLowerCase()) {
      case 'student':
        return ChatSenderType.student;
      case 'educator':
        return ChatSenderType.educator;
      default:
        return ChatSenderType.other;
    }
  }
}

/// Media kind for a [ChatMessage]. Drives which renderer the message
/// bubble uses (plain text vs. image preview vs. file chip). Unknown
/// values collapse to [text] so older / non-conforming payloads still
/// render with a sensible fallback.
enum ChatMessageType {
  text,
  image,
  file,
  audio;

  static ChatMessageType fromWire(Object? raw) {
    if (raw is! String) return ChatMessageType.text;
    switch (raw.trim().toLowerCase()) {
      case 'image':
        return ChatMessageType.image;
      case 'file':
        return ChatMessageType.file;
      case 'audio':
        return ChatMessageType.audio;
      case 'text':
      default:
        return ChatMessageType.text;
    }
  }

  String get wireValue {
    switch (this) {
      case ChatMessageType.text:
        return 'Text';
      case ChatMessageType.image:
        return 'Image';
      case ChatMessageType.file:
        return 'File';
      case ChatMessageType.audio:
        return 'Audio';
    }
  }
}

/// A single chat message — used for both REST history items and the
/// payloads pushed by the SignalR `ReceiveMessage` event. The model is
/// deliberately tolerant of slightly different shapes the backend uses
/// in those two paths (e.g. casing of property names) by reading each
/// field through both spellings where they differ.
class ChatMessage {
  final int id;
  final String groupId;
  final int senderId;
  final ChatSenderType senderType;
  final String senderName;
  final String message;
  final ChatMessageType messageType;

  /// Network URL when the message carries non-text media. Null for
  /// plain text messages.
  final String? mediaUrl;

  final DateTime createdAt;

  /// When the author last rewrote this message, or null if they never
  /// did. Drives the small "edited" marker beside the timestamp.
  ///
  /// Deliberately a **separate column from `updatedAt`** server-side:
  /// `updated_at` also moves on a soft delete, so it cannot mean
  /// "edited".
  final DateTime? editedAt;

  /// Set when this message is a reply. The full referenced message is
  /// surfaced via [replyTo] when the backend includes it inline; the
  /// id alone is enough for the bubble to render a "replying to…" hint
  /// and scroll to the target when the user taps it.
  final int? replyToMessageId;
  final ChatMessage? replyTo;

  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.createdAt,
    this.mediaUrl,
    this.editedAt,
    this.replyToMessageId,
    this.replyTo,
  });

  bool get isFromCurrentStudent => senderType == ChatSenderType.student;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isEdited => editedAt != null;

  /// Whether the app should *offer* an edit affordance on this bubble.
  ///
  /// Author-only and text-only — deliberately narrower than [canDelete],
  /// because rewriting someone's words while they stay attributed to
  /// that person is misrepresentation, so there is no staff override
  /// server-side either.
  ///
  /// **Time-dependent — never cache this.** It has to be read at the
  /// moment the menu opens (or off a periodic tick), otherwise a menu
  /// built on render still offers Edit ten minutes later.
  ///
  /// [createdAt] is already `.toLocal()`, so comparing it against
  /// `DateTime.now()` is correct — do not re-convert.
  bool get canEdit =>
      isFromCurrentStudent &&
      messageType == ChatMessageType.text &&
      _withinWindow(ChatLimits.editWindow);

  /// Whether the app should *offer* a delete affordance. Author-only,
  /// and remember this removes the message for **both** sides.
  ///
  /// Same caching caveat as [canEdit].
  bool get canDelete =>
      isFromCurrentStudent && _withinWindow(ChatLimits.deleteWindow);

  /// Both windows anchor on [createdAt], never [editedAt] — see
  /// [ChatLimits]. This reads the device clock, which the user can
  /// change; that only affects whether the button shows, since the
  /// server compares against its own clock and still refuses.
  bool _withinWindow(Duration window) =>
      DateTime.now().difference(createdAt) < window;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? raw) {
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toLocal();
      }
      return DateTime.now();
    }

    /// Nullable twin of `parseDate` — an absent `editedAt` must stay
    /// null (it means "never edited"), not fall back to "now".
    DateTime? parseNullableDate(Object? raw) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw)?.toLocal();
      }
      return null;
    }

    final replyToRaw = json['replyTo'];
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      groupId: json['groupId']?.toString() ?? '',
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      senderType: ChatSenderType.fromWire(json['senderType']),
      senderName: json['senderName']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      messageType: ChatMessageType.fromWire(json['messageType']),
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: parseDate(json['createdAt']),
      editedAt: parseNullableDate(json['editedAt']),
      replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
      replyTo: replyToRaw is Map<String, dynamic>
          ? ChatMessage.fromJson(replyToRaw)
          : null,
    );
  }

  ChatMessage copyWith({String? groupId, String? message, DateTime? editedAt}) {
    return ChatMessage(
      id: id,
      groupId: groupId ?? this.groupId,
      senderId: senderId,
      senderType: senderType,
      senderName: senderName,
      message: message ?? this.message,
      messageType: messageType,
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );
  }
}

/// Paged history response from `GET /api/v1/chat-group/{groupId}/messages`.
class PagedChatMessages {
  final List<ChatMessage> messages;
  final int page;
  final int pageSize;
  final bool hasMore;

  const PagedChatMessages({
    required this.messages,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory PagedChatMessages.fromJson(Map<String, dynamic> json) {
    final rawList = json['messages'];
    final messages = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList()
        : <ChatMessage>[];
    return PagedChatMessages(
      messages: messages,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? messages.length,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
