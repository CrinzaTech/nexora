/// Notification entity mirroring `GET /api/v1/notifications`.
///
/// Live response shape:
/// ```json
/// {
///   "notificationId": 42,
///   "title": "string",
///   "message": "string",
///   "imageUrl": "string",
///   "referenceValue": "string",
///   "createdAt": "2026-05-12T16:57:50",
///   "notificationType": "course",
///   "isRead": false
/// }
/// ```
///
/// [referenceValue] is the routing payload — its meaning depends on
/// [notificationType]:
///
/// | type           | what referenceValue holds          |
/// | -------------- | ---------------------------------- |
/// | `course`       | course id (int as string)          |
/// | `category`     | category id (int as string)        |
/// | `externalLink` | a full URL to open                 |
/// | `none`         | unused                             |
library;

/// Routing payload type — drives what happens when the user taps the
/// notification card. Unknown / missing values from the backend fall
/// back to [none] so the tap simply marks-as-read without navigating.
enum NotificationType {
  none,
  course,
  category,
  externalLink;

  /// Wire-format string the backend sends. Centralised so the parser
  /// and any future "build a notification for testing" code share one
  /// source of truth.
  String get wireValue {
    switch (this) {
      case NotificationType.none:
        return 'none';
      case NotificationType.course:
        return 'course';
      case NotificationType.category:
        return 'category';
      case NotificationType.externalLink:
        return 'externalLink';
    }
  }

  /// Parse the backend's string into the enum. Case-insensitive so a
  /// future "Course" vs "course" wobble doesn't break routing. Unknown
  /// strings (and null) collapse to [none].
  static NotificationType fromWire(Object? raw) {
    if (raw is! String) return NotificationType.none;
    final normalised = raw.trim().toLowerCase();
    switch (normalised) {
      case 'course':
        return NotificationType.course;
      case 'category':
        return NotificationType.category;
      case 'externallink':
        return NotificationType.externalLink;
      case 'none':
      case '':
      default:
        return NotificationType.none;
    }
  }
}

class NotificationModel {
  /// Backend's `notificationId` (int).
  final int id;
  final String title;
  final String message;
  final String? imageUrl;

  /// Routing payload — id-as-string for `course` / `category`, a full
  /// URL for `externalLink`. See [NotificationType] for details.
  final String? referenceValue;

  /// Parsed from ISO-8601. Falls back to `DateTime.now()` if the string is
  /// missing / malformed (defensive — never crashes the page).
  final DateTime createdAt;

  /// Drives tap-routing. See [NotificationType].
  final NotificationType notificationType;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    this.referenceValue,
    required this.createdAt,
    this.notificationType = NotificationType.none,
    this.isRead = false,
  });

  /// Returns a new instance with the supplied fields overridden. Used by
  /// the cubit's optimistic mark-as-read update so we don't have to
  /// re-fetch the whole list just to flip one boolean.
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      imageUrl: imageUrl,
      referenceValue: referenceValue,
      createdAt: createdAt,
      notificationType: notificationType,
      isRead: isRead ?? this.isRead,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['notificationId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      imageUrl: json['imageUrl'] as String?,
      referenceValue: json['referenceValue']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      notificationType: NotificationType.fromWire(json['notificationType']),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}
