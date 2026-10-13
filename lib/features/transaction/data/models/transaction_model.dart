/// Transaction status returned by the backend.
///
/// Backend ships `SUCCESS` / `FAILED` / `PENDING` (uppercase). Parser is
/// case-insensitive and tolerates a few legacy spellings ("completed",
/// "refunded") so older endpoints can still feed the same model.
/// Anything else falls into [TransactionStatus.unknown] so the UI keeps
/// rendering instead of throwing.
enum TransactionStatus {
  completed,
  pending,
  failed,
  refunded,
  unknown;

  static TransactionStatus fromString(String? raw) {
    if (raw == null) return TransactionStatus.unknown;
    switch (raw.trim().toLowerCase()) {
      case 'completed':
      case 'success':
        return TransactionStatus.completed;
      case 'pending':
      case 'processing':
        return TransactionStatus.pending;
      case 'failed':
      case 'failure':
        return TransactionStatus.failed;
      case 'refunded':
      case 'refund':
        return TransactionStatus.refunded;
      default:
        return TransactionStatus.unknown;
    }
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
      case TransactionStatus.unknown:
        return 'Unknown';
    }
  }
}

/// What a transaction paid for.
enum TransactionItemType {
  /// A course or webinar payment. Its document is the course receipt.
  course,

  /// A store order. Its document is the order's invoice (or a payment
  /// receipt until it ships), fetched by order number.
  product;

  static TransactionItemType fromString(String? raw) =>
      raw?.trim().toUpperCase() == 'PRODUCT'
      ? TransactionItemType.product
      : TransactionItemType.course;
}

/// A single transaction record returned by `GET /api/v1/course/transaction-history`.
///
/// The endpoint lists course payments and store orders together, newest
/// first; [itemType] tells them apart.
///
/// All fields are nullable-safe — partial responses (e.g. an in-flight
/// payment without a Razorpay order id yet) won't crash parsing.
class TransactionModel {
  /// Course transaction id: the receipt key. Null for store orders,
  /// which are opened by [orderNo].
  final int? transactionId;

  final TransactionItemType itemType;

  /// Store order number (store orders only).
  final String? orderNo;

  /// Invoice number once a store order has shipped; null before that
  /// (its document is then a payment receipt) and for courses.
  final String? invoiceNo;

  /// Products in a store order; 1 for a course.
  final int itemCount;

  /// Amount paid, in rupees.
  final double? amount;

  /// Buyer display name.
  final String? userName;

  /// What was bought: the course / webinar, or the order's first product
  /// ("… + 2 more items").
  final String? courseName;

  /// Status of the transaction.
  final TransactionStatus status;

  /// Payment method label (`netbanking` / `card` / `upi` / etc.).
  final String? paymentMethod;

  /// Razorpay order reference, when present.
  final String? razorpayOrderId;

  /// Server-side creation timestamp, parsed to local time. Null when the
  /// API ships an empty / malformed value.
  final DateTime? createdAt;

  const TransactionModel({
    this.transactionId,
    this.itemType = TransactionItemType.course,
    this.orderNo,
    this.invoiceNo,
    this.itemCount = 1,
    this.amount,
    this.userName,
    this.courseName,
    this.status = TransactionStatus.unknown,
    this.paymentMethod,
    this.razorpayOrderId,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
    }

    return TransactionModel(
      transactionId: (json['transactionId'] as num?)?.toInt(),
      itemType: TransactionItemType.fromString(json['itemType']?.toString()),
      orderNo: json['orderNo']?.toString(),
      invoiceNo: json['invoiceNo']?.toString(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 1,
      amount: (json['amount'] as num?)?.toDouble(),
      userName: json['userName']?.toString(),
      courseName: json['courseName']?.toString(),
      status: TransactionStatus.fromString(json['paymentStatus']?.toString()),
      paymentMethod: json['paymentMethod']?.toString(),
      razorpayOrderId: json['razorpayOrderId']?.toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }

  bool get isProduct => itemType == TransactionItemType.product;

  /// Whether tapping the row can open a document: a course receipt by
  /// transaction id, or a store order's invoice / receipt by order number.
  /// A failed store payment has nothing to show.
  bool get hasDocument => isProduct
      ? (orderNo != null && status != TransactionStatus.failed)
      : transactionId != null;
}
