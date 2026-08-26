enum CourseContentType {
  folder,
  video,

  /// Lecture hosted on YouTube. The `url` field holds a public YouTube URL
  /// (watch / youtu.be / shorts); we render it through the in-app player
  /// without revealing the source. From the user's perspective it behaves
  /// like a regular video node — same icon, same routing target.
  youtube,
  image,
  document,
  zip,
  assignment,

  /// Interactive exam node. The `url` field holds the exam id (as a
  /// string); tapping opens the in-app exam-taking flow (ExamPage).
  exam,

  /// Scheduled live-streamed class. The `url` field holds the **roomId**
  /// (like `assignment` carries a numeric id — NOT an HLS URL); the
  /// player page resolves a signed HLS URL through the stream proxy at
  /// join time. `startDateTime` + `durationSeconds` drive the
  /// upcoming / live-now / ended presentation.
  liveClass;

  /// Parses the `type` string sent by the backend. Case-insensitive.
  static CourseContentType fromString(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'folder':
        return CourseContentType.folder;
      case 'video':
        return CourseContentType.video;
      case 'youtube':
      case 'yt':
        return CourseContentType.youtube;
      case 'image':
        return CourseContentType.image;
      case 'document':
      case 'pdf':
      case 'doc':
        return CourseContentType.document;
      case 'zip':
        return CourseContentType.zip;
      case 'assignment':
        return CourseContentType.assignment;
      case 'exam':
        return CourseContentType.exam;
      // Backend sends exactly `liveClass`; the lowercased switch maps it
      // via the `liveclass` case. The other spellings are defensive.
      case 'liveclass':
      case 'live_class':
      case 'live':
        return CourseContentType.liveClass;
      default:
        return CourseContentType.folder;
    }
  }
}

/// Summary model returned by list APIs:
/// - `GET /api/v1/course/tile/{tileId}`
/// - `GET /api/v1/course/category/{categoryId}`
/// And used inside the dashboard's `trendingCourses` section.
class CourseSummary {
  final int courseId;
  final String courseTitle;
  final String courseImageUrl;
  final double rating;
  final int totalReviewsCounts;
  final int category;
  final bool isPurchased;

  /// Optional progress percentage `0..100` returned by purchased-course
  /// list endpoints. Null on endpoints that don't include it (trending,
  /// etc.). The UI appends the `%` symbol at display time.
  final double? courseCompletionPercentage;

  /// Number of content nodes the course exposes. Null when the endpoint
  /// doesn't include it.
  final int? contentCount;

  /// Human-readable category label (e.g. "UPSC Exams"). Sent by some
  /// endpoints alongside `categoryId`. Null when only the id is shipped.
  final String? categoryName;

  /// Date the user's access to a purchased course expires. Drives the
  /// "Access until …" / "Expired on …" badge on the My Courses
  /// → Completed tab. Null on endpoints that don't include it.
  final DateTime? accessUntil;

  /// Server-side row id for this user's purchase of the course. Used
  /// as the path param for purchase-scoped endpoints (currently the
  /// rewatch reset). Only set on `/my-courses` responses.
  final int? purchasedId;

  /// Whether the educator issues a certificate for this course. Shipped
  /// by `/my-courses`; defaults to `false` on endpoints that don't send
  /// it, which is the safe read — a course with no certificate returns
  /// 404 from the download endpoint, so the button stays hidden rather
  /// than making a round trip that can only fail.
  final bool hasCertificate;

  /// `true` when the course costs nothing, so list/continue cards can
  /// label their CTA "Get Free Access" instead of "Buy Now".
  ///
  /// List endpoints ship no price breakdown (that only arrives with the
  /// detail/pricing calls), so this is read defensively off whichever
  /// free-marker the endpoint happens to send — see [_readIsFree].
  /// Defaults to `false`, which keeps the existing "Buy Now" copy when
  /// the backend sends no marker at all.
  final bool isCourseFree;

  const CourseSummary({
    required this.courseId,
    required this.courseTitle,
    required this.courseImageUrl,
    required this.rating,
    required this.totalReviewsCounts,
    required this.category,
    this.isPurchased = false,
    this.courseCompletionPercentage,
    this.contentCount,
    this.categoryName,
    this.accessUntil,
    this.purchasedId,
    this.hasCertificate = false,
    this.isCourseFree = false,
  });

  /// Maps the backend's `0..100` completion percentage to a `0..1`
  /// ratio for [LinearProgressIndicator]. Returns `0` when missing.
  double get progressRatio {
    final raw = courseCompletionPercentage;
    if (raw == null) return 0;
    return (raw / 100).clamp(0.0, 1.0);
  }

  /// "30%" / "100%" — UI helper that appends the `%` symbol the backend
  /// dropped when it switched to a numeric field. Strips trailing `.0`
  /// for whole numbers.
  String get progressLabel {
    final raw = courseCompletionPercentage ?? 0;
    final s = raw % 1 == 0 ? raw.toStringAsFixed(0) : raw.toStringAsFixed(1);
    return '$s%';
  }

  /// `true` once completion is reported as ≥ 100% — used to split the
  /// "In Progress" and "Completed" tabs of My Courses.
  bool get isCompleted => progressRatio >= 1.0;

  /// `true` when the access window has expired. Treats null/no-expiry as
  /// open-ended access so we don't accidentally mark courses expired
  /// when the field hasn't shipped.
  bool get isAccessExpired {
    final until = accessUntil;
    return until != null && DateTime.now().isAfter(until);
  }

  CourseSummary copyWith({
    int? courseId,
    String? courseTitle,
    String? courseImageUrl,
    double? rating,
    int? totalReviewsCounts,
    int? category,
    bool? isPurchased,
    double? courseCompletionPercentage,
    int? contentCount,
    String? categoryName,
    DateTime? accessUntil,
    int? purchasedId,
    bool? hasCertificate,
    bool? isCourseFree,
  }) {
    return CourseSummary(
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      courseImageUrl: courseImageUrl ?? this.courseImageUrl,
      rating: rating ?? this.rating,
      totalReviewsCounts: totalReviewsCounts ?? this.totalReviewsCounts,
      category: category ?? this.category,
      isPurchased: isPurchased ?? this.isPurchased,
      courseCompletionPercentage:
          courseCompletionPercentage ?? this.courseCompletionPercentage,
      contentCount: contentCount ?? this.contentCount,
      categoryName: categoryName ?? this.categoryName,
      accessUntil: accessUntil ?? this.accessUntil,
      purchasedId: purchasedId ?? this.purchasedId,
      hasCertificate: hasCertificate ?? this.hasCertificate,
      isCourseFree: isCourseFree ?? this.isCourseFree,
    );
  }

  factory CourseSummary.fromJson(Map<String, dynamic> json) {
    // Backend is inconsistent across endpoints:
    // - tile/category/trending use `totalReviewsCounts` + `category`
    // - continue-course/search use `totalReviewsCount` + `categoryId`
    // Read either spelling so the same model handles all five list endpoints.
    final reviewsCount =
        json['totalReviewsCount'] ?? json['totalReviewsCounts'];
    final categoryRaw = json['categoryId'] ?? json['category'];
    final accessRaw =
        json['accessUntil'] ?? json['accessExpiryDate'] ?? json['expiresAt'];
    return CourseSummary(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseTitle: json['courseTitle'] as String? ?? '',
      courseImageUrl: json['courseImageUrl'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviewsCounts: (reviewsCount as num?)?.toInt() ?? 0,
      category: (categoryRaw is num) ? categoryRaw.toInt() : 0,
      isPurchased: json['isPurchased'] as bool? ?? false,
      // Backend now sends a number (0..100). Tolerate the old string
      // form ("30%") just in case a stale endpoint hasn't rolled over.
      courseCompletionPercentage: _readPercentage(
        json['courseCompletionPercentage'],
      ),
      contentCount: (json['contentCount'] as num?)?.toInt(),
      categoryName:
          (json['categoryName'] ?? (categoryRaw is String ? categoryRaw : null))
              ?.toString(),
      accessUntil: accessRaw == null
          ? null
          : DateTime.tryParse(accessRaw.toString())?.toLocal(),
      purchasedId: (json['purchasedId'] as num?)?.toInt(),
      // Read the aliases too — the flag is new on `/my-courses` and the
      // backend has form for shipping the same field under a second
      // name (see `totalReviewsCount` / `categoryId` above).
      hasCertificate:
          (json['hasCertificate'] ??
                  json['isCertificateAvailable'] ??
                  json['certificateAvailable'])
              as bool? ??
          false,
      isCourseFree: _readIsFree(json),
    );
  }

  /// Resolves whether a list-endpoint course is free.
  ///
  /// The list payloads carry no price breakdown, and the backend hasn't
  /// settled on one spelling for the flag, so every plausible marker is
  /// checked in turn:
  ///  1. an explicit boolean (`isCourseFree` / `isFree` / `isPaid`),
  ///  2. the catalog's `courseType` string ("free" / "paid"),
  ///  3. a price field that is present *and* zero.
  ///
  /// A missing price is never read as free — absent data means unknown,
  /// and the card falls back to "Buy Now".
  static bool _readIsFree(Map<String, dynamic> json) {
    final explicit = json['isCourseFree'] ?? json['isFree'];
    if (explicit is bool) return explicit;
    if (json['isPaid'] is bool) return !(json['isPaid'] as bool);

    final type = json['courseType']?.toString().toLowerCase();
    if (type == 'free') return true;
    if (type == 'paid') return false;

    final price =
        json['calculatedFinalPrice'] ??
        json['finalPrice'] ??
        json['discountedPrice'] ??
        json['price'];
    if (price is num) return price <= 0;

    return false;
  }

  /// Reads `courseCompletionPercentage` from the response. Backend now
  /// sends a number (`0..100`); we still tolerate the legacy `"30%"`
  /// string form so a stale endpoint can't break the model parse.
  static double? _readPercentage(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll('%', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// One row of the `data.pricing.pricing[]` array returned by the course
/// detail v2 endpoint. Each tier is a distinct buy option (price ×
/// duration combination) and carries its own `coursePricingId` — the
/// id that downstream v2 calls (pricing-v2 + create-order-v2) use to
/// pin the exact tier the user is paying for.
class CoursePricingTier {
  final int coursePricingId;

  /// Backend-internal enum (e.g. fixed-duration vs. custom-expiry).
  /// Surfaced as a raw int — the UI doesn't branch on it today; kept
  /// on the model so future copy ("Lifetime access" / "Subscription")
  /// can read it without another endpoint round.
  final int courseValidityType;

  /// Backend-internal enum for the unit of [durationOfCourse]
  /// (e.g. days / months). Same rationale as [courseValidityType].
  final int durationType;

  /// Number of [durationType] units the tier grants access for.
  final int durationOfCourse;

  /// Explicit expiry date when [courseValidityType] is "custom" —
  /// otherwise null and access is computed from [durationOfCourse].
  final DateTime? customExpiryDate;

  /// MRP of the tier before any discount — the strikethrough price.
  final double originalPrice;

  /// Discount **amount** (rupees saved), not the post-discount price.
  /// Confirmed against v2: `originalPrice - discountedPrice ==
  /// calculatedFinalPrice` (e.g. 2000 − 1500 = 500). Not currently
  /// displayed; kept on the model so a future "You save ₹X" row
  /// drops in without touching the parser.
  final double discountedPrice;

  /// Price the user actually pays for the tier (post-discount, pre-
  /// tax). Drives the bold price line on the plan card.
  final double calculatedFinalPrice;

  /// Human discount label (e.g. "43% OFF"). Empty / null when the tier
  /// has no discount.
  final String? discountText;

  const CoursePricingTier({
    required this.coursePricingId,
    required this.courseValidityType,
    required this.durationType,
    required this.durationOfCourse,
    this.customExpiryDate,
    required this.originalPrice,
    required this.discountedPrice,
    required this.calculatedFinalPrice,
    this.discountText,
  });

  bool get hasDiscount =>
      calculatedFinalPrice > 0 && calculatedFinalPrice < originalPrice;

  factory CoursePricingTier.fromJson(Map<String, dynamic> json) {
    final expiryRaw = json['customExpiryDate'];
    return CoursePricingTier(
      coursePricingId: (json['coursePricingId'] as num?)?.toInt() ?? 0,
      courseValidityType: (json['courseValidityType'] as num?)?.toInt() ?? 0,
      durationType: (json['durationType'] as num?)?.toInt() ?? 0,
      durationOfCourse: (json['durationOfCourse'] as num?)?.toInt() ?? 0,
      customExpiryDate: expiryRaw == null
          ? null
          : DateTime.tryParse(expiryRaw.toString())?.toLocal(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discountedPrice'] as num?)?.toDouble() ?? 0.0,
      calculatedFinalPrice:
          (json['calculatedFinalPrice'] as num?)?.toDouble() ?? 0.0,
      discountText: json['discountText'] as String?,
    );
  }
}

/// Full course detail returned by `GET /api/v1/course/{courseId}/v2`.
class Course {
  final int courseId;
  final String courseTitle;
  final String courseImageUrl;
  final double totalRating;
  final int totalReviewsCounts;
  final String? description;
  final int coursePurchasedId;
  final bool isPurchased;

  /// `true` when the course is free of charge and the buy flow should
  /// short-circuit straight to enrolment without hitting Razorpay.
  /// Mirrors the same flag echoed by `create-order-v2`.
  final bool isCourseFree;

  /// Human-readable access-window label (e.g. "Access for 2 months",
  /// "109567 days remaining"). Sent verbatim by v2 — we don't try to
  /// re-derive it client-side.
  final String? expiryDetails;

  /// Tier list returned by v2 under `data.pricing.pricing[]`. Empty
  /// when the course has no buyable tier (typically a free course).
  /// Drives the buy-flow's "which priceId to charge?" decision and
  /// the original/discounted price chip on the detail page.
  final List<CoursePricingTier> pricing;

  final CourseNodes? courseNodes;

  const Course({
    required this.courseId,
    required this.courseTitle,
    required this.courseImageUrl,
    required this.totalRating,
    required this.totalReviewsCounts,
    this.description,
    this.coursePurchasedId = 0,
    this.isPurchased = false,
    this.isCourseFree = false,
    this.expiryDetails,
    this.pricing = const [],
    this.courseNodes,
  });

  /// First tier returned by the backend — used as the default selection
  /// when the user hasn't picked one (today the UI assumes a single
  /// tier; a future selector will let the user choose).
  CoursePricingTier? get primaryPricing =>
      pricing.isEmpty ? null : pricing.first;

  // ── Back-compat getters ────────────────────────────────────────────
  // v1 surfaced these as top-level fields; v2 moves them inside the
  // pricing array. We expose them as computed reads off [primaryPricing]
  // so existing UI ([course_detail_page.dart]) keeps working unchanged.

  double? get finalPrice => primaryPricing?.calculatedFinalPrice;
  double? get originalPrice => primaryPricing?.originalPrice;
  String? get discountText => primaryPricing?.discountText;
  bool get hasDiscount => primaryPricing?.hasDiscount ?? false;

  factory Course.fromJson(Map<String, dynamic> json) {
    // v2 wraps the tier list inside `pricing.pricing[]` (the outer
    // `pricing` also carries a `count`); parse defensively so a flat
    // legacy shape still produces an empty list rather than throwing.
    final pricingBlock = json['pricing'];
    final tierList =
        (pricingBlock is Map<String, dynamic>
            ? pricingBlock['pricing']
            : null) ??
        const [];
    return Course(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseTitle: json['courseTitle'] as String? ?? '',
      courseImageUrl: json['courseImageUrl'] as String? ?? '',
      totalRating: (json['totalRating'] as num?)?.toDouble() ?? 0.0,
      totalReviewsCounts: (json['totalReviewsCounts'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      coursePurchasedId: (json['coursePurchasedId'] as num?)?.toInt() ?? 0,
      isPurchased: json['isPurchased'] as bool? ?? false,
      isCourseFree: json['isCourseFree'] as bool? ?? false,
      expiryDetails: json['expiryDetails'] as String?,
      pricing: (tierList as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CoursePricingTier.fromJson)
          .toList(),
      courseNodes: json['courseNodes'] is Map<String, dynamic>
          ? CourseNodes.fromJson(json['courseNodes'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Wrapper for the root content tree of a course.
class CourseNodes {
  final int courseId;
  final String courseName;
  final bool activateWatermark;
  final List<CourseContent> content;

  const CourseNodes({
    required this.courseId,
    required this.courseName,
    this.activateWatermark = false,
    required this.content,
  });

  factory CourseNodes.fromJson(Map<String, dynamic> json) {
    return CourseNodes(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName'] as String? ?? '',
      activateWatermark: json['activateWatermark'] as bool? ?? false,
      content: (json['content'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CourseContent.fromJson)
          .toList(),
    );
  }
}

/// Returned by `GET /api/v1/course/{courseId}/reviews`
/// and `POST /api/v1/course/review`.
class CourseReview {
  final int reviewId;
  final String? learnerName;
  final String? profileImageUrl;
  final String reviewDate;
  final String reviewMessage;
  final double courseRating;
  final int courseId;
  final String courseName;

  const CourseReview({
    required this.reviewId,
    this.learnerName,
    this.profileImageUrl,
    required this.reviewDate,
    required this.reviewMessage,
    required this.courseRating,
    required this.courseId,
    this.courseName = '',
  });

  /// "AB" → first letters of first two words; falls back to first letter.
  String get initials {
    final name = (learnerName ?? '').trim();
    if (name.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  factory CourseReview.fromJson(Map<String, dynamic> json) {
    return CourseReview(
      reviewId: (json['reviewId'] as num?)?.toInt() ?? 0,
      learnerName: json['learnerName'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      reviewDate: json['reviewDate']?.toString() ?? '',
      reviewMessage: json['reviewMessage']?.toString() ?? '',
      courseRating: (json['courseRating'] as num?)?.toDouble() ?? 0.0,
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName']?.toString() ?? '',
    );
  }
}

/// Recursive tree node for course content (folders, videos, images, documents,
/// zips).
class CourseContent {
  final String nodeId;
  final String nodeName;
  final CourseContentType type;
  final bool isLocked;
  final bool isVisible;
  // Single URL field — the API now sends `url` for all content types.
  // Kept as named getters below for call-site compat.
  final String? url;
  final int? durationSeconds;
  final List<CourseContent> children;

  /// Scheduled start time for time-bound nodes (live sessions, scheduled
  /// assignments, etc.). Null on nodes that are immediately available.
  final DateTime? startDateTime;

  const CourseContent({
    required this.nodeId,
    required this.nodeName,
    required this.type,
    this.isLocked = false,
    this.isVisible = true,
    this.url,
    this.durationSeconds,
    this.children = const [],
    this.startDateTime,
  });

  bool get isFolder => type == CourseContentType.folder;
  bool get isLiveClass => type == CourseContentType.liveClass;

  // ── Live-class time state ──────────────────────────────────────────
  // `startDateTime` is already `.toLocal()`-converted at parse time —
  // compare/format directly, do NOT re-convert.

  /// Scheduled end of the live window; null when either the start or the
  /// duration is missing (treated as an open-ended session).
  DateTime? get _liveEnd => (startDateTime != null && durationSeconds != null)
      ? startDateTime!.add(Duration(seconds: durationSeconds!))
      : null;

  bool get isUpcoming =>
      startDateTime != null && DateTime.now().isBefore(startDateTime!);

  bool get isLiveNow =>
      startDateTime != null &&
      !DateTime.now().isBefore(startDateTime!) &&
      (_liveEnd == null || DateTime.now().isBefore(_liveEnd!));

  bool get isEnded => _liveEnd != null && !DateTime.now().isBefore(_liveEnd!);

  // Backward-compat getters so existing call-sites don't need to change.
  String? get videoUrl => type == CourseContentType.video ? url : null;
  String? get imageUrl => type == CourseContentType.image ? url : null;
  String? get pdfUrl =>
      (type == CourseContentType.document || type == CourseContentType.zip)
      ? url
      : null;

  /// Formatted "MM:SS" or "HH:MM:SS" from durationSeconds.
  String? get formattedDuration {
    final s = durationSeconds;
    if (s == null || s <= 0) return null;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final seconds = s % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// The content URL for this node, or null for folders.
  String? get primaryUrl => type == CourseContentType.folder ? null : url;

  /// Number of playable/openable nodes inside this folder that the user
  /// can access without enrolling — i.e. visible, non-folder descendants
  /// with `isLocked == false`, counted recursively through sub-folders.
  ///
  /// Derived entirely from the curriculum tree the detail endpoint
  /// already returns, so no extra API call is needed. Folders themselves
  /// are never counted — only the leaf content inside them.
  int get freeContentCount {
    var count = 0;
    for (final child in children) {
      if (!child.isVisible) continue;
      if (child.isFolder) {
        count += child.freeContentCount;
      } else if (!child.isLocked) {
        count++;
      }
    }
    return count;
  }

  factory CourseContent.fromJson(Map<String, dynamic> json) {
    // API sends a single `url` field; fall back to the old per-type fields
    // for any cached or legacy responses.
    final url =
        json['url'] as String? ??
        json['videoUrl'] as String? ??
        json['imageUrl'] as String? ??
        json['pdfUrl'] as String?;
    final startRaw = json['startDateTime'];
    return CourseContent(
      nodeId: json['nodeId'] as String? ?? '',
      nodeName: json['nodeName'] as String? ?? '',
      type: CourseContentType.fromString(json['type'] as String? ?? 'folder'),
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      url: url,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      // Backend sends `children: null` for leaf nodes; default to an
      // empty list so callers can iterate without a null-check.
      children: (json['children'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseContent.fromJson)
          .toList(),
      startDateTime: startRaw == null
          ? null
          : DateTime.tryParse(startRaw.toString())?.toLocal(),
    );
  }
}

/// Backend-calculated price breakdown returned by
/// `GET /api/v1/course/pricing-v2?CourseId=&PriceId=`.
///
/// Drives the order-summary numbers on the enrolment bottom sheet so the
/// figures the user sees match exactly what Razorpay will charge. Bound
/// to one tier via [coursePriceId]; the cubit re-fetches when the user
/// switches tier so the breakdown stays in sync with the selected tier.
class CoursePricing {
  final int courseId;

  /// Echo of the `PriceId` query param the request was made with —
  /// surfaces the tier this breakdown belongs to. `0` only when the
  /// backend didn't echo it back (older shape, defensive fallback).
  final int coursePriceId;

  final String courseTitle;
  final String courseImageUrl;
  final double originalPrice;
  final double discountedPrice;
  final double internetChargesAmount;
  final double taxAppliedPercentage;
  final double platformFees;
  final bool isShipmentAvailable;
  final bool isGstPaidByStudent;

  /// Human-readable access-window label echoed by v2 (e.g.
  /// "Access for 2 months"). Empty when the backend doesn't ship one.
  final String expiryDetails;

  /// Discount label as shown by the backend, e.g. "23%". Empty when the
  /// course has no discount.
  final String totalDiscountGranted;

  /// The actual course price granted to the student, in rupees. When
  /// [isGstPaidByStudent] is `false` (GST inclusive), this — not
  /// [originalPrice] — is the correct "Course Price" to display, since
  /// `originalPrice` is the tax-inclusive total in that case.
  final double totalGrantedAmount;

  // ── Coupon fields ──────────────────────────────────────────────────
  // Populated only when the GET request was made with a `couponCode`
  // query param. Backend echoes the coupon's validity outcome in the
  // pricing response so the UI can refresh the breakdown + show the
  // validity message in one round-trip.

  /// Coupon validity flag from the backend. Observed values so far:
  /// `2` = "Coupon code not found" (sample response). `null` when no
  /// coupon was sent. Higher-level code reads [isCouponApplied] /
  /// [hasCouponMessage] rather than poking at the int directly so the
  /// mapping can change without touching the UI.
  final int? couponStatus;

  /// Human-readable validity message from the backend, e.g.
  /// "Coupon code not found." Shown below the coupon input.
  final String? couponValidityMessage;

  /// Discount unit when the coupon is valid (`PERCENT` / `FLAT` etc).
  /// Null until the backend documents the spelling — read defensively.
  final String? couponDiscountType;

  /// Rupee amount the coupon takes off the cart total. `0` for an
  /// invalid coupon, `>0` when the coupon was accepted.
  final double couponOfferAmount;

  /// Total rupee discount (item discount + coupon discount combined)
  /// once the coupon is applied. `0` when no coupon is applied.
  final double couponDiscountedRemainAmount;

  /// Coupon discount expressed as a percentage, e.g. `15` for 15%.
  /// `0` when no coupon is applied.
  final double couponDiscountPercentageValue;

  const CoursePricing({
    required this.courseId,
    required this.coursePriceId,
    required this.courseTitle,
    required this.courseImageUrl,
    required this.originalPrice,
    required this.discountedPrice,
    required this.internetChargesAmount,
    required this.taxAppliedPercentage,
    required this.platformFees,
    required this.isShipmentAvailable,
    this.isGstPaidByStudent = false,
    this.expiryDetails = '',
    required this.totalDiscountGranted,
    required this.totalGrantedAmount,
    this.couponStatus,
    this.couponValidityMessage,
    this.couponDiscountType,
    this.couponOfferAmount = 0,
    this.couponDiscountedRemainAmount = 0,
    this.couponDiscountPercentageValue = 0,
  });

  /// `true` when the backend returned a non-zero coupon discount —
  /// safest cross-version signal that a coupon was actually applied.
  bool get isCouponApplied => couponOfferAmount > 0;

  /// `true` when the validity message slot has text to show below the
  /// coupon field (regardless of validity).
  bool get hasCouponMessage =>
      couponValidityMessage != null && couponValidityMessage!.isNotEmpty;

  /// Subtotal the tax is applied against — `(originalPrice - discountedPrice)` minus
  /// any accepted coupon. Floored at 0 so a generous coupon doesn't
  /// produce negative tax.
  double get _taxableSubtotal =>
      ((originalPrice - discountedPrice) - couponOfferAmount).clamp(
        0.0,
        double.infinity,
      );

  /// Tax rupee value derived from the post-coupon subtotal × the
  /// percentage. Computed on the client because the backend only
  /// returns the percentage.
  double get taxAmount {
    final rate = taxAppliedPercentage > 0 ? taxAppliedPercentage : 18.0;
    if (isGstPaidByStudent) {
      return _taxableSubtotal * (rate / 100);
    } else {
      return _taxableSubtotal - (_taxableSubtotal / (1 + (rate / 100)));
    }
  }

  /// Final amount the user is charged: post-coupon subtotal + tax +
  /// internet charges + platform fees. Floored at 0.
  double get totalPayable {
    if (isGstPaidByStudent) {
      return (_taxableSubtotal +
              taxAmount +
              internetChargesAmount +
              platformFees)
          .clamp(0.0, double.infinity);
    } else {
      return (_taxableSubtotal + internetChargesAmount + platformFees).clamp(
        0.0,
        double.infinity,
      );
    }
  }

  factory CoursePricing.fromJson(Map<String, dynamic> json) {
    return CoursePricing(
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      coursePriceId: (json['coursePriceId'] as num?)?.toInt() ?? 0,
      courseTitle: json['courseTitle'] as String? ?? '',
      courseImageUrl: json['courseImageUrl'] as String? ?? '',
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discountedPrice'] as num?)?.toDouble() ?? 0.0,
      internetChargesAmount:
          (json['internetChargesAmount'] as num?)?.toDouble() ?? 0.0,
      taxAppliedPercentage:
          (json['taxAppliedPercentage'] as num?)?.toDouble() ?? 0.0,
      platformFees: (json['platformFees'] as num?)?.toDouble() ?? 0.0,
      isShipmentAvailable: json['isShipmentAvailable'] as bool? ?? false,
      isGstPaidByStudent: json['isGstPaidByStudent'] as bool? ?? false,
      expiryDetails: json['expiryDetails'] as String? ?? '',
      totalDiscountGranted: json['totalDiscountGranted'] as String? ?? '',
      totalGrantedAmount:
          (json['totalGrantedAmount'] as num?)?.toDouble() ?? 0.0,
      couponStatus: (json['couponStatus'] as num?)?.toInt(),
      couponValidityMessage: json['couponValidityMessage']?.toString(),
      couponDiscountType: json['couponDiscountType']?.toString(),
      couponOfferAmount: (json['couponOfferAmount'] as num?)?.toDouble() ?? 0.0,
      couponDiscountedRemainAmount:
          (json['couponDiscountedRemainAmount'] as num?)?.toDouble() ?? 0.0,
      couponDiscountPercentageValue:
          (json['couponDiscountPercentageValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CourseCatalogResponse {
  final List<CourseSummary> courses;
  final int? totalCount;
  final int? pageNo;
  final int? totalPages;

  const CourseCatalogResponse({
    required this.courses,
    this.totalCount,
    this.pageNo,
    this.totalPages,
  });

  factory CourseCatalogResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<CourseSummary> coursesList = [];
    int? totalCount;
    int? pageNo;
    int? totalPages;

    if (data is List) {
      coursesList = data
          .whereType<Map<String, dynamic>>()
          .map(CourseSummary.fromJson)
          .toList();
    } else if (data is Map<String, dynamic>) {
      final listData = data['courses'] ?? data['items'] ?? data['data'] ?? [];
      if (listData is List) {
        coursesList = listData
            .whereType<Map<String, dynamic>>()
            .map(CourseSummary.fromJson)
            .toList();
      }
      totalCount =
          (data['totalCount'] ?? data['total'] ?? data['totalRecords']) as int?;
      pageNo = (data['pageNo'] ?? data['page'] ?? data['currentPage']) as int?;
      totalPages = (data['totalPages'] ?? data['pages']) as int?;
    }
    return CourseCatalogResponse(
      courses: coursesList,
      totalCount: totalCount,
      pageNo: pageNo,
      totalPages: totalPages,
    );
  }
}
