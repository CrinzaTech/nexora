/// Course chat group returned by `GET /api/v1/chat-group`.
///
/// Hand-written for type tolerance — the backend has been inconsistent on
/// numeric vs. string IDs across other endpoints, so we coerce defensively.
class ChatGroupModel {
  final int groupId;

  /// Firebase Realtime DB / Firestore identifier — the actual chat
  /// transport ID. Kept verbatim because that's how Firebase will index it.
  final String firebaseGroupId;
  final String groupName;
  final String groupDescription;
  final String? groupImageUrl;

  /// ISO 8601 datetime string from the backend. Parsed lazily via
  /// [createdAtDate] so we don't crash on malformed input.
  final String groupCreatedAt;

  /// `false` for read-only / announcement groups.
  final bool canUserReply;

  const ChatGroupModel({
    required this.groupId,
    required this.firebaseGroupId,
    required this.groupName,
    this.groupDescription = '',
    this.groupImageUrl,
    this.groupCreatedAt = '',
    this.canUserReply = true,
  });

  /// Parsed [groupCreatedAt]; null if the string is missing / malformed.
  DateTime? get createdAtDate =>
      groupCreatedAt.isEmpty ? null : DateTime.tryParse(groupCreatedAt);

  factory ChatGroupModel.fromJson(Map<String, dynamic> json) {
    return ChatGroupModel(
      groupId: (json['groupId'] as num?)?.toInt() ?? 0,
      firebaseGroupId: json['firebaseGroupId']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      groupDescription: json['groupDescription']?.toString() ?? '',
      groupImageUrl: json['groupImageUrl'] as String?,
      groupCreatedAt: json['groupCreatedAt']?.toString() ?? '',
      canUserReply: json['canUserReply'] as bool? ?? true,
    );
  }
}
