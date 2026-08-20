/// One row of `GET /api/v1/certificate/completed` — a course the learner
/// has finished, plus whether a certificate exists for it.
///
/// The learner is taken from the JWT, so nothing here identifies a user;
/// [courseId] is the only thing the download endpoint needs.
class CompletedCourse {
  /// The enrolment row. Used as the list key — a learner can hold two
  /// enrolments in the same course, so `courseId` alone isn't unique.
  final int purchasedId;

  /// What gets passed to the download endpoint.
  final int courseId;

  final String courseName;

  /// S3 object key, **not** a URL. The app has no key→URL resolver, so
  /// [thumbnailUrl] only surfaces it when the backend happens to ship a
  /// full URL; otherwise the card falls back to an icon.
  final String? thumbnail;

  final DateTime purchasedAt;

  /// When the last lesson was finished. Null for older enrolments that
  /// pre-date completion tracking — never force-unwrap it.
  final DateTime? completedAt;

  /// Whether a download is possible at all. The educator sets this per
  /// course; false means there is no certificate and calling download
  /// would 404, so this is what gates the button.
  final bool hasCertificate;

  /// Already downloaded at least once.
  final bool isIssued;

  /// Set once issued, then fixed forever — safe to cache and display.
  final String? certificateNo;

  final DateTime? issuedAt;

  const CompletedCourse({
    required this.purchasedId,
    required this.courseId,
    required this.courseName,
    required this.purchasedAt,
    required this.hasCertificate,
    required this.isIssued,
    this.thumbnail,
    this.completedAt,
    this.certificateNo,
    this.issuedAt,
  });

  /// The thumbnail as something [CustomNetworkImage] can actually load.
  ///
  /// The API ships an S3 object key (`courses/images/9f2c.jpg`) and this
  /// app resolves images from absolute URLs only, so a bare key is
  /// reported as "no image" rather than handed over as a broken URL.
  String? get thumbnailUrl {
    final raw = thumbnail?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : null;
  }

  factory CompletedCourse.fromJson(Map<String, dynamic> json) {
    return CompletedCourse(
      purchasedId: (json['purchasedId'] as num?)?.toInt() ?? 0,
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      purchasedAt: _parseDate(json['purchasedAt']) ?? DateTime.now(),
      completedAt: _parseDate(json['completedAt']),
      hasCertificate: json['hasCertificate'] as bool? ?? false,
      isIssued: json['isIssued'] as bool? ?? false,
      certificateNo: json['certificateNo'] as String?,
      issuedAt: _parseDate(json['issuedAt']),
    );
  }

  /// Tolerant date read — the nullable fields are genuinely null on old
  /// enrolments, and a malformed string shouldn't take the whole list
  /// parse down with it.
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}

/// A certificate PDF that has been fetched and written to disk.
class DownloadedCertificate {
  /// Absolute path inside the app's documents directory (not the cache
  /// directory — the OS may clear caches at any time, and a learner
  /// expects a saved certificate to still be there).
  final String path;

  /// Read off the `X-Certificate-No` response header, so the number can
  /// be shown without parsing the PDF.
  final String certificateNo;

  /// The course this belongs to — used for the preview page's title.
  final String courseName;

  const DownloadedCertificate({
    required this.path,
    required this.certificateNo,
    required this.courseName,
  });
}
