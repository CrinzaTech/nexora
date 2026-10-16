/// News & Updates models, mirroring `/api/v1/news*`.
///
/// One item shape is shared by every endpoint:
/// ```json
/// {
///   "newsId": 42,
///   "title": "New batch for Class 12 Physics starts Monday",
///   "message": "Limited seats.\nEarly-bird price till Sunday.",
///   "type": "Offer",
///   "imageUrl": "https://…presigned…",
///   "actionType": "Course",
///   "actionValue": "118",
///   "actionLabel": "Enroll now",
///   "publishedAtUtc": "2026-10-15T06:30:00Z",
///   "expiresAtUtc": "2026-10-22T06:30:00Z",
///   "isRead": false
/// }
/// ```
library;

/// The label chip on a post. Unknown values read as [news].
enum NewsType {
  news,
  update,
  offer,
  event,
  important;

  String get label => switch (this) {
    NewsType.news => 'News',
    NewsType.update => 'Update',
    NewsType.offer => 'Offer',
    NewsType.event => 'Event',
    NewsType.important => 'Important',
  };

  /// Case-insensitive; anything unrecognised (or null) is [news].
  static NewsType fromWire(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final type in NewsType.values) {
      if (type.name == value) return type;
    }
    return NewsType.news;
  }
}

/// What the post's button does. [none] means there is no button.
enum NewsActionType {
  none,
  externalLink,
  course;

  /// Case-insensitive; anything unrecognised (or null) is [none].
  static NewsActionType fromWire(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'externallink':
        return NewsActionType.externalLink;
      case 'course':
        return NewsActionType.course;
      default:
        return NewsActionType.none;
    }
  }
}

class NewsItem {
  final int newsId;
  final String title;

  /// Plain text; keeps its `\n` line breaks.
  final String message;
  final NewsType type;

  /// Presigned and short-lived (~30 min). Never cache by this URL —
  /// `CustomNetworkImage` keys its cache on the path without the query.
  final String? imageUrl;
  final NewsActionType actionType;

  /// A full `https://` URL for [NewsActionType.externalLink], the course id
  /// as a string for [NewsActionType.course].
  final String? actionValue;
  final String? actionLabel;

  /// Local time.
  final DateTime publishedAt;

  /// Local time. Null means the post never expires.
  final DateTime? expiresAt;
  final bool isRead;

  const NewsItem({
    required this.newsId,
    required this.title,
    required this.message,
    required this.type,
    this.imageUrl,
    this.actionType = NewsActionType.none,
    this.actionValue,
    this.actionLabel,
    required this.publishedAt,
    this.expiresAt,
    this.isRead = false,
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  /// Whether to show the button at all. The server already sends `None`
  /// for a course that was unpublished after the post was written.
  bool get hasAction => actionType != NewsActionType.none;

  /// The server always fills [actionLabel] when there is a button; these
  /// are its own defaults, used only if that ever slips.
  String get buttonLabel {
    final label = actionLabel?.trim() ?? '';
    if (label.isNotEmpty) return label;
    return actionType == NewsActionType.course ? 'View course' : 'Open link';
  }

  NewsItem copyWith({bool? isRead}) => NewsItem(
    newsId: newsId,
    title: title,
    message: message,
    type: type,
    imageUrl: imageUrl,
    actionType: actionType,
    actionValue: actionValue,
    actionLabel: actionLabel,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    isRead: isRead ?? this.isRead,
  );

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final image = json['imageUrl']?.toString().trim();
    return NewsItem(
      newsId: (json['newsId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: NewsType.fromWire(json['type']),
      imageUrl: (image == null || image.isEmpty) ? null : image,
      actionType: NewsActionType.fromWire(json['actionType']),
      actionValue: json['actionValue']?.toString(),
      actionLabel: json['actionLabel']?.toString(),
      publishedAt: _parseUtc(json['publishedAtUtc']) ?? DateTime.now(),
      expiresAt: _parseUtc(json['expiresAtUtc']),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// The API sends UTC with a `Z`; shown in the device's local time.
  static DateTime? _parseUtc(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Identity is the id: two copies of a post differing only in [isRead]
  /// are different values, so a read flip still rebuilds the list.
  @override
  bool operator ==(Object other) =>
      other is NewsItem && other.newsId == newsId && other.isRead == isRead;

  @override
  int get hashCode => Object.hash(newsId, isRead);
}

/// `GET /api/v1/news/home`.
class NewsHomeSummary {
  final int unreadCount;

  /// Newest first, at most 5. Usually empty.
  final List<NewsItem> popups;

  const NewsHomeSummary({required this.unreadCount, required this.popups});

  factory NewsHomeSummary.fromJson(Map<String, dynamic> json) =>
      NewsHomeSummary(
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        popups: _items(json['popups']),
      );
}

/// `GET /api/v1/news?pageNo=&pageSize=`. An empty [items] is a normal
/// answer ("No news right now."), not an error.
class NewsPage {
  final int unreadCount;
  final int totalCount;
  final int pageNo;

  /// Read back from the response: the server clamps it, so this is what
  /// the next page request repeats.
  final int pageSize;
  final bool hasMore;
  final List<NewsItem> items;

  const NewsPage({
    required this.unreadCount,
    required this.totalCount,
    required this.pageNo,
    required this.pageSize,
    required this.hasMore,
    required this.items,
  });

  factory NewsPage.fromJson(Map<String, dynamic> json) => NewsPage(
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    pageNo: (json['pageNo'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
    hasMore: json['hasMore'] as bool? ?? false,
    items: _items(json['items']),
  );
}

List<NewsItem> _items(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e)))
          .toList()
    : const [];
