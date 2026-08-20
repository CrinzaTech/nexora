import 'package:flutter/foundation.dart';

/// Root dashboard payload returned by `GET /api/v1/dashboard`.
///
/// Hand-written (no Freezed JSON) so we can tolerate the backend occasionally
/// sending numeric fields as strings — e.g. `"rating": "4.5"` instead of 4.5.
class DashboardData {
  final int notificationCount;
  final List<BannerItem> banner;
  final List<EducatorTile> educatorTiles;
  final List<TrendingCourse> trendingCourses;
  final List<NewCourse> newCourses;
  final List<LearnerReview> learnerReviews;
  final List<SocialMediaLink> socialMediaLinks;

  const DashboardData({
    this.notificationCount = 0,
    this.banner = const [],
    this.educatorTiles = const [],
    this.trendingCourses = const [],
    this.newCourses = const [],
    this.learnerReviews = const [],
    this.socialMediaLinks = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      notificationCount: _toInt(json['notificationCount']) ?? 0,
      banner: _parseList(json['banner'], BannerItem.fromJson),
      educatorTiles: _parseList(json['educatorTiles'], EducatorTile.fromJson),
      trendingCourses: _parseList(
        json['trendingCourses'],
        TrendingCourse.fromJson,
      ),
      newCourses: _parseList(
        json['newCourses'],
        NewCourse.fromJson,
      ),
      learnerReviews: _parseList(
        json['learnerReviews'],
        LearnerReview.fromJson,
      ),
      socialMediaLinks: _parseList(
        json['socialMediaLinks'],
        SocialMediaLink.fromJson,
      ),
    );
  }
}

/// Action type associated with a banner tap.
///
/// Mirrors the admin panel `BANNER_ROUTES_TYPE` dropdown:
///   1 = No Redirect   (no action on tap)
///   2 = Specific Course (ctaLink = courseId → course detail)
///   3 = Specific Tile  (ctaLink = tileId  → catalog filtered by tile)
///   4 = External URL   (ctaLink = full URL → system browser)
enum BannerCtaType {
  none,          // 1
  specificCourse, // 2
  specificTile,   // 3 — ctaLink carries a tileId
  externalLink,  // 4
  unknown;

  static BannerCtaType fromRaw(String raw) {
    switch (raw.trim()) {
      // ── String-name format (what the API currently sends) ──
      case 'none':
        return BannerCtaType.none;

      case 'specificCourse':
        return BannerCtaType.specificCourse;

      case 'specificTile':
        return BannerCtaType.specificTile;

      case 'externalLink':
        return BannerCtaType.externalLink;
        
      default:
        return BannerCtaType.unknown;
    }
  }
}

class BannerItem {
  final int bannerId;
  final String imageUrl;
  final String ctaType;
  final String ctaLink;

  /// Display name for the linked destination when [ctaType] is
  /// `specificCourse` or `specificTile`. Returned directly by the API so
  /// no client-side lookup is required.
  final String ctaName;

  const BannerItem({
    required this.bannerId,
    required this.imageUrl,
    this.ctaType = '',
    this.ctaLink = '',
    this.ctaName = '',
  });

  /// Strongly-typed view of [ctaType].
  BannerCtaType get ctaTypeEnum => BannerCtaType.fromRaw(ctaType);

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    // ── Debug: dump the raw banner JSON to verify field names ──
    debugPrint('[BannerItem.fromJson] raw keys=${json.keys.toList()} | ctaType=${json['ctaType']} | ctaLink=${json['ctaLink']} | ctaName=${json['ctaName']}');
    return BannerItem(
      bannerId: _toInt(json['bannerId']) ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      ctaType: json['ctaType']?.toString() ?? '',
      ctaLink: json['ctaLink']?.toString() ?? '',
      ctaName: json['ctaName']?.toString() ?? '',
    );
  }
}

class EducatorTile {
  final int tileId;
  final String tileName;
  final String tileLogoURL;

  const EducatorTile({
    required this.tileId,
    required this.tileName,
    required this.tileLogoURL,
  });

  factory EducatorTile.fromJson(Map<String, dynamic> json) {
    return EducatorTile(
      tileId: _toInt(json['tileId']) ?? 0,
      tileName: json['tileName']?.toString() ?? '',
      tileLogoURL:
          json['tileLogoURL']?.toString() ??
          json['tileLogoUrl']?.toString() ??
          '',
    );
  }
}

class TrendingCourse {
  final int courseId;
  final String courseTitle;
  final String courseImageUrl;
  final double rating;
  final int totalReviewsCounts;
  final int category;

  const TrendingCourse({
    required this.courseId,
    required this.courseTitle,
    required this.courseImageUrl,
    this.rating = 0.0,
    this.totalReviewsCounts = 0,
    this.category = 0,
  });

  factory TrendingCourse.fromJson(Map<String, dynamic> json) {
    return TrendingCourse(
      courseId: _toInt(json['courseId']) ?? 0,
      courseTitle: json['courseTitle']?.toString() ?? '',
      courseImageUrl: json['courseImageUrl']?.toString() ?? '',
      rating: _toDouble(json['rating']) ?? 0.0,
      totalReviewsCounts: _toInt(json['totalReviewsCounts']) ?? 0,
      category: _toInt(json['category']) ?? 0,
    );
  }
}

class NewCourse {
  final int courseId;
  final String courseTitle;
  final String courseImageUrl;
  final double rating;
  final int totalReviewsCounts;
  final int category;

  const NewCourse({
    required this.courseId,
    required this.courseTitle,
    required this.courseImageUrl,
    this.rating = 0.0,
    this.totalReviewsCounts = 0,
    this.category = 0,
  });

  factory NewCourse.fromJson(Map<String, dynamic> json) {
    return NewCourse(
      courseId: _toInt(json['courseId']) ?? 0,
      courseTitle: json['courseTitle']?.toString() ?? '',
      courseImageUrl: json['courseImageUrl']?.toString() ?? '',
      rating: _toDouble(json['rating']) ?? 0.0,
      totalReviewsCounts: _toInt(json['totalReviewsCounts']) ?? 0,
      category: _toInt(json['category']) ?? 0,
    );
  }
}

class LearnerReview {
  final int reviewId;
  final String learnerName;
  final String profileImageUrl;
  final String reviewDate;
  final String reviewMessage;
  final double courseRating;
  final int courseId;

  /// Optional title of the reviewed course. Tolerated as empty when the
  /// backend hasn't started returning it yet — the UI only renders it
  /// when present.
  final String courseTitle;

  const LearnerReview({
    required this.reviewId,
    required this.learnerName,
    this.profileImageUrl = '',
    required this.reviewDate,
    this.reviewMessage = '',
    this.courseRating = 0.0,
    this.courseId = 0,
    this.courseTitle = '',
  });

  factory LearnerReview.fromJson(Map<String, dynamic> json) {
    return LearnerReview(
      reviewId: _toInt(json['reviewId']) ?? 0,
      learnerName: json['learnerName']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString() ?? '',
      reviewDate: json['reviewDate']?.toString() ?? '',
      reviewMessage: json['reviewMessage']?.toString() ?? '',
      courseRating: _toDouble(json['courseRating']) ?? 0.0,
      courseId: _toInt(json['courseId']) ?? 0,
      courseTitle: json['courseName']?.toString() ?? '',
    );
  }
}

/// A single social-media platform link returned by the dashboard API.
///
/// Example JSON:
/// ```json
/// { "title": "Youtube", "icon": "crinza_admin/Live/.../icon.png", "link": "https://..." }
/// ```
class SocialMediaLink {
  final String title;
  final String icon;
  final String link;

  const SocialMediaLink({
    required this.title,
    required this.icon,
    required this.link,
  });

  factory SocialMediaLink.fromJson(Map<String, dynamic> json) {
    return SocialMediaLink(
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
    );
  }
}

// ---- Defensive coercion helpers ----
// Tolerates num, int, double, and numeric strings.

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return <T>[];
  return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
}
