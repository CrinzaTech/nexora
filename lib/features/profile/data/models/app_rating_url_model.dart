/// Response model for `GET /api/v1/UserAuth/app-rating-url`.
///
/// [ratingUrl] is `null` when the organization hasn't configured a
/// rating URL for the requested platform — treat that as "no redirect
/// available" rather than an error.
class AppRatingUrlModel {
  final String? ratingUrl;

  const AppRatingUrlModel({this.ratingUrl});

  factory AppRatingUrlModel.fromJson(Map<String, dynamic> json) {
    // The URL normally lives at data.ratingUrl, but be defensive about
    // casing (ratingUrl / RatingUrl / rating_url) and the occasional
    // flat envelope where it sits at the top level instead of under
    // `data`. Fall back through both containers before giving up.
    final data = json['data'];
    final container = data is Map<String, dynamic> ? data : json;
    return AppRatingUrlModel(ratingUrl: _readUrl(container));
  }

  static String? _readUrl(Map<String, dynamic> map) {
    const keys = ['ratingUrl', 'RatingUrl', 'rating_url', 'url', 'Url'];
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}
