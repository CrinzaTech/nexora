/// Course bundle models — B1–B3, P1, P2 and the X2 related-course card.
/// See BUNDLE_API.md.
///
/// The one rule the shapes here enforce: **every figure is the server's.**
/// Prices, savings, "your price" and the whole checkout breakdown are
/// read and shown as sent, never derived — the app has no say in what a
/// bundle costs, and the server prices it again on P1 regardless.
library;

import 'package:nexora/features/store/data/models/store_common_model.dart';

/// B1 / B3 card — and the head of every B2 payload.
class BundleCard {
  final int bundleId;
  final String title;
  final String? imageUrl;
  final int courseCount;

  /// The courses bought one by one. Shown struck through.
  final double actualPrice;

  /// The bundle price before tax and fees. The headline figure.
  final double price;
  final int discountPercent;
  final double savings;

  /// One line under the price, e.g. "Each course keeps its own access".
  final String accessText;

  /// Courses in the bundle this learner already has valid access to.
  final int ownedCount;

  /// What **this learner** pays before tax and fees. Below [price] only
  /// when the educator discounts already-owned courses.
  final double yourPrice;

  final bool isPurchased;

  /// False hides Buy; [purchaseBlockedReason] says why.
  final bool canPurchase;
  final String? purchaseBlockedReason;

  const BundleCard({
    required this.bundleId,
    required this.title,
    this.imageUrl,
    this.courseCount = 0,
    this.actualPrice = 0,
    this.price = 0,
    this.discountPercent = 0,
    this.savings = 0,
    this.accessText = '',
    this.ownedCount = 0,
    this.yourPrice = 0,
    this.isPurchased = false,
    this.canPurchase = false,
    this.purchaseBlockedReason,
  });

  factory BundleCard.fromJson(Map<String, dynamic> json) => BundleCard(
    bundleId: readInt(json['bundleId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    courseCount: readInt(json['courseCount']),
    actualPrice: readDouble(json['actualPrice']),
    price: readDouble(json['price']),
    discountPercent: readInt(json['discountPercent']),
    savings: readDouble(json['savings']),
    accessText: readString(json['accessText']),
    ownedCount: readInt(json['ownedCount']),
    yourPrice: readDouble(json['yourPrice'], readDouble(json['price'])),
    isPurchased: readBool(json['isPurchased']),
    canPurchase: readBool(json['canPurchase']),
    purchaseBlockedReason: readStringOrNull(json['purchaseBlockedReason']),
  );

  /// "Your price ₹3,200" earns its place only when it differs.
  bool get hasPersonalPrice => yourPrice < price;

  bool get hasDiscount => discountPercent > 0 || savings > 0;
}

/// What buying the bundle does for one course in it.
enum BundleCourseOutcome {
  /// Being bought. Nothing extra to say.
  newCourse,

  /// Owned; the bundle extends the access.
  extend,

  /// Owned with equal or longer access; the bundle leaves it alone.
  keepCurrent,

  /// Owned, and taken off the price.
  ownedNotCharged;

  static BundleCourseOutcome fromWire(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'EXTEND':
        return BundleCourseOutcome.extend;
      case 'KEEP_CURRENT':
        return BundleCourseOutcome.keepCurrent;
      case 'OWNED_NOT_CHARGED':
        return BundleCourseOutcome.ownedNotCharged;
      default:
        return BundleCourseOutcome.newCourse;
    }
  }

  /// The note under the course, or null when there is nothing to add.
  String? get note => switch (this) {
    BundleCourseOutcome.newCourse => null,
    BundleCourseOutcome.extend => 'You own this. Your access will be extended.',
    BundleCourseOutcome.keepCurrent =>
      'You already own this with equal or longer access. Your access '
          'stays as it is.',
    BundleCourseOutcome.ownedNotCharged => 'You already own this. Not charged.',
  };
}

/// One course inside a B2 bundle.
class BundleCourse {
  final int courseId;
  final String title;
  final String? imageUrl;
  final double price;
  final double originalPrice;
  final String accessText;
  final bool isOwned;

  /// Local time. Set only when [isOwned]; null with [isOwned] means
  /// lifetime access.
  final DateTime? currentAccessExpiresAt;
  final BundleCourseOutcome outcome;

  const BundleCourse({
    required this.courseId,
    required this.title,
    this.imageUrl,
    this.price = 0,
    this.originalPrice = 0,
    this.accessText = '',
    this.isOwned = false,
    this.currentAccessExpiresAt,
    this.outcome = BundleCourseOutcome.newCourse,
  });

  factory BundleCourse.fromJson(Map<String, dynamic> json) => BundleCourse(
    courseId: readInt(json['courseId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    price: readDouble(json['price']),
    originalPrice: readDouble(json['originalPrice']),
    accessText: readString(json['accessText']),
    isOwned: readBool(json['isOwned']),
    currentAccessExpiresAt: readDate(json['currentAccessExpiresAt']),
    outcome: BundleCourseOutcome.fromWire(readStringOrNull(json['outcome'])),
  );
}

/// The checkout breakdown — B2's `pricing`, and P1's again. Rendered
/// line by line exactly as sent.
class BundlePricing {
  final double actualPrice;
  final double bundleDiscount;
  final int ownedCourseCount;
  final double ownedReduction;
  final double subtotal;
  final double gstPercentage;
  final double gstAmount;

  /// True: GST is already inside [subtotal] — an info line, added to
  /// nothing. False: GST is a charge on top.
  final bool isGstInclusive;
  final double internetChargesPercentage;
  final double internetCharges;
  final double platformFeesPercentage;
  final double platformFees;

  /// Exactly what P1 will charge, unless something changed in between.
  final double totalPayable;
  final String currency;

  const BundlePricing({
    this.actualPrice = 0,
    this.bundleDiscount = 0,
    this.ownedCourseCount = 0,
    this.ownedReduction = 0,
    this.subtotal = 0,
    this.gstPercentage = 0,
    this.gstAmount = 0,
    this.isGstInclusive = false,
    this.internetChargesPercentage = 0,
    this.internetCharges = 0,
    this.platformFeesPercentage = 0,
    this.platformFees = 0,
    this.totalPayable = 0,
    this.currency = 'INR',
  });

  factory BundlePricing.fromJson(Map<String, dynamic> json) => BundlePricing(
    actualPrice: readDouble(json['actualPrice']),
    bundleDiscount: readDouble(json['bundleDiscount']),
    ownedCourseCount: readInt(json['ownedCourseCount']),
    ownedReduction: readDouble(json['ownedReduction']),
    subtotal: readDouble(json['subtotal']),
    gstPercentage: readDouble(json['gstPercentage']),
    gstAmount: readDouble(json['gstAmount']),
    isGstInclusive: readBool(json['isGstInclusive']),
    internetChargesPercentage: readDouble(json['internetChargesPercentage']),
    internetCharges: readDouble(json['internetCharges']),
    platformFeesPercentage: readDouble(json['platformFeesPercentage']),
    platformFees: readDouble(json['platformFees']),
    totalPayable: readDouble(json['totalPayable']),
    currency: readString(json['currency'], 'INR'),
  );
}

/// B2 — the bundle page.
class BundleDetail {
  final BundleCard card;
  final String? description;

  /// The educator discounts courses the learner already owns.
  final bool adjustForOwned;
  final List<BundleCourse> courses;
  final BundlePricing pricing;

  const BundleDetail({
    required this.card,
    this.description,
    this.adjustForOwned = false,
    this.courses = const [],
    this.pricing = const BundlePricing(),
  });

  factory BundleDetail.fromJson(Map<String, dynamic> json) => BundleDetail(
    card: BundleCard.fromJson(json),
    description: readStringOrNull(json['description']),
    adjustForOwned: readBool(json['adjustForOwned']),
    courses: readList(json['courses'], BundleCourse.fromJson),
    pricing: BundlePricing.fromJson(readMap(json['pricing'])),
  );

  int get bundleId => card.bundleId;
}

/// P1 — a Razorpay order, priced entirely server-side.
class BundleOrder {
  final String razorpayOrderId;

  /// Publishable key for the current environment. Never hardcoded.
  final String keyId;

  /// **What goes to Razorpay.** Paise: ₹4,040.32 is 404032.
  final int amountPaise;

  /// Display only, and the figure compared against what the checkout
  /// showed to catch a price that moved.
  final double amountRupees;
  final String currency;
  final String receiptNo;
  final String bundleTitle;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;

  /// An open order from the last 30 minutes was handed back.
  final bool isReused;
  final BundlePricing pricing;

  const BundleOrder({
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
    required this.amountRupees,
    this.currency = 'INR',
    this.receiptNo = '',
    this.bundleTitle = '',
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
    this.isReused = false,
    this.pricing = const BundlePricing(),
  });

  factory BundleOrder.fromJson(Map<String, dynamic> json) => BundleOrder(
    razorpayOrderId: readString(json['razorpayOrderId']),
    keyId: readString(json['keyId']),
    amountPaise: readInt(json['amountPaise']),
    amountRupees: readDouble(json['amountRupees']),
    currency: readString(json['currency'], 'INR'),
    receiptNo: readString(json['receiptNo']),
    bundleTitle: readString(json['bundleTitle']),
    prefillName: readStringOrNull(json['prefillName']),
    prefillEmail: readStringOrNull(json['prefillEmail']),
    prefillContact: readStringOrNull(json['prefillContact']),
    isReused: readBool(json['isReused']),
    pricing: BundlePricing.fromJson(readMap(json['pricing'])),
  );

  /// Enough to open the sheet with. A blank key or order id is a 200
  /// with nothing usable — caught here rather than inside the SDK.
  bool get isUsable =>
      razorpayOrderId.isNotEmpty && keyId.isNotEmpty && amountPaise > 0;
}

/// P2 — the authoritative answer on whether the courses unlocked.
///
/// Three outcomes, read from the flags and never from the HTTP status:
/// [paid] (unlocked), [pending] (captured but not yet confirmed — **never
/// offer to pay again**), or neither (failed, and [message] says why).
class BundlePaymentResult {
  final bool paid;
  final bool pending;
  final String message;
  final int bundleId;

  const BundlePaymentResult({
    required this.paid,
    required this.pending,
    required this.message,
    this.bundleId = 0,
  });

  factory BundlePaymentResult.fromJson(Map<String, dynamic> json) =>
      BundlePaymentResult(
        paid: readBool(json['paid']),
        pending: readBool(json['pending']),
        message: readString(json['message']),
        bundleId: readInt(json['bundleId']),
      );
}

/// X2 — a course linked to a Store product.
class RelatedCourse {
  final int courseId;
  final String title;
  final String? imageUrl;

  /// The course's cheapest plan: shown as "from ₹1,000".
  final double price;
  final double originalPrice;
  final bool isFree;

  const RelatedCourse({
    required this.courseId,
    required this.title,
    this.imageUrl,
    this.price = 0,
    this.originalPrice = 0,
    this.isFree = false,
  });

  factory RelatedCourse.fromJson(Map<String, dynamic> json) => RelatedCourse(
    courseId: readInt(json['courseId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    price: readDouble(json['price']),
    originalPrice: readDouble(json['originalPrice']),
    isFree: readBool(json['isFree']),
  );
}
