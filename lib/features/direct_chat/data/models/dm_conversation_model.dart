/// One row of the learner's personal-chat inbox — a private 1-to-1
/// thread between this learner and a member of the org's staff.
///
/// Ships from two places with an identical shape:
///   - `GET /api/v1/direct-chat/conversations` (the inbox list)
///   - the hub's `DirectInboxUpdated` event, which is addressed to the
///     user by id and therefore arrives even when the learner is not
///     inside the thread.
///
/// [otherUserAvatarUrl] is always null on this side of the app — the
/// backend's `users` table has no image column for staff — so the UI
/// renders initials. Do not treat null as an error.
class DmConversation {
  /// Opaque, server-issued thread id (e.g. `dm:CRINZA:e3:s142`). It
  /// looks guessable and it is; never build one client-side. Always
  /// take it from the API or a hub payload.
  final String conversationKey;

  /// `users.id` of the staff member on the other end.
  final int otherUserId;

  /// `educator` / `admin` / … — role label, not a display string.
  final String otherUserType;

  final String otherUserName;

  /// Human-readable role line ("Faculty"). May be empty.
  final String otherUserSubtitle;

  final String? otherUserAvatarUrl;

  /// Staff-controlled. History stays readable but sending stops for
  /// both sides. Updated live via `DirectConversationBlockChanged`.
  final bool isBlocked;

  final int unreadCount;

  /// Null on a thread that has been opened but never used — those sort
  /// to the top of the inbox.
  final DateTime? lastMessageAt;

  final String lastMessagePreview;

  const DmConversation({
    required this.conversationKey,
    required this.otherUserId,
    required this.otherUserType,
    required this.otherUserName,
    required this.otherUserSubtitle,
    required this.isBlocked,
    required this.unreadCount,
    required this.lastMessagePreview,
    this.otherUserAvatarUrl,
    this.lastMessageAt,
  });

  bool get hasUnread => unreadCount > 0;

  /// Initials for the avatar fallback — staff have no image, so this is
  /// what actually renders in the inbox.
  String get initials => initialsOf(otherUserName);

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    final avatar = json['otherUserAvatarUrl']?.toString();
    final lastAtRaw = json['lastMessageAt']?.toString();
    return DmConversation(
      conversationKey: json['conversationKey']?.toString() ?? '',
      // Tolerant of both numeric and string ids — the SP projection and
      // the hub serialiser have disagreed on this in the past.
      otherUserId: _toInt(json['otherUserId']),
      otherUserType: json['otherUserType']?.toString() ?? '',
      otherUserName: json['otherUserName']?.toString() ?? '',
      otherUserSubtitle: json['otherUserSubtitle']?.toString() ?? '',
      otherUserAvatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
      isBlocked: json['isBlocked'] as bool? ?? false,
      unreadCount: _toInt(json['unreadCount']),
      lastMessageAt: (lastAtRaw != null && lastAtRaw.isNotEmpty)
          // Server writes `created_at` at +05:30, same as group chat.
          // `.toLocal()` normalises it; do not "fix" the offset.
          ? DateTime.tryParse(lastAtRaw)?.toLocal()
          : null,
      lastMessagePreview: json['lastMessagePreview']?.toString() ?? '',
    );
  }

  DmConversation copyWith({
    bool? isBlocked,
    int? unreadCount,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) {
    return DmConversation(
      conversationKey: conversationKey,
      otherUserId: otherUserId,
      otherUserType: otherUserType,
      otherUserName: otherUserName,
      otherUserSubtitle: otherUserSubtitle,
      otherUserAvatarUrl: otherUserAvatarUrl,
      isBlocked: isBlocked ?? this.isBlocked,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}

/// One staff member the learner is allowed to message, from
/// `GET /api/v1/direct-chat/directory`.
///
/// [conversationKey] is precomputed by the server — use it to look the
/// entry up in the inbox before spending a `POST /conversations`.
class DmDirectoryEntry {
  final int userId;
  final String userType;
  final String userName;
  final String userSubtitle;
  final String? userAvatarUrl;
  final String conversationKey;

  const DmDirectoryEntry({
    required this.userId,
    required this.userType,
    required this.userName,
    required this.userSubtitle,
    required this.conversationKey,
    this.userAvatarUrl,
  });

  String get initials => initialsOf(userName);

  factory DmDirectoryEntry.fromJson(Map<String, dynamic> json) {
    final avatar = json['userAvatarUrl']?.toString();
    return DmDirectoryEntry(
      userId: _toInt(json['userId']),
      userType: json['userType']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userSubtitle: json['userSubtitle']?.toString() ?? '',
      userAvatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
      conversationKey: json['conversationKey']?.toString() ?? '',
    );
  }
}

/// Ids arrive as `num` over REST and occasionally as `String` through
/// the hub serialiser — accept both rather than silently zeroing out.
int _toInt(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

/// Up to two letters taken from the first and last word of a name
/// ("Priya Sharma" → "PS", "Priya" → "P"). Falls back to `?` on an
/// empty name so the avatar never renders blank.
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}'
          '${parts.last.substring(0, 1)}'
      .toUpperCase();
}
