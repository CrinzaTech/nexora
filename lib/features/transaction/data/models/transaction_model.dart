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

/// A single transaction record returned by `GET /api/v1/course/transaction-history`.
///
/// All fields are nullable-safe — partial responses (e.g. an in-flight
/// payment without a Razorpay order id yet) won't crash parsing.
class TransactionModel {
  /// Backend transaction row id (numeric).
  final int? transactionId;

  /// Buyer display name.
  final String? userName;

  /// Course this transaction was for.
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
      userName: json['userName']?.toString(),
      courseName: json['courseName']?.toString(),
      status: TransactionStatus.fromString(json['paymentStatus']?.toString()),
      paymentMethod: json['paymentMethod']?.toString(),
      razorpayOrderId: json['razorpayOrderId']?.toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
