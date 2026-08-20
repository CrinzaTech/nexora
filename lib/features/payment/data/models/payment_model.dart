/// Model for the Razorpay order created by the backend.
///
/// Live response shape:
/// ```json
/// {
///   "isCourseFree": false,
///   "key": "rzp_test_…",
///   "orderId": "order_…",
///   "amount": 6458,
///   "currency": "INR",
///   "receipt": "COURSE_3_3_…"
/// }
/// ```
///
/// `isCourseFree` short-circuits the Razorpay flow entirely — when
/// true, the backend has already enrolled the user (e.g. a 100%-off
/// coupon brought the bill to zero) and the client just needs to fire
/// the success path. The other fields feed [Razorpay.open] for the
/// non-free case.
///
/// Parses both flat and `{ data: {...} }`-nested shapes so the model
/// keeps working if the backend wraps the response later.
class CreateOrderResponse {
  final String orderId;
  final int amount;
  final String currency;
  final String keyId;

  /// `true` when no payment is required — caller should skip Razorpay
  /// and treat the purchase as complete.
  final bool isCourseFree;

  /// Backend-issued receipt id. Surface only for support / debugging
  /// (Razorpay's SDK doesn't need it).
  final String receipt;

  const CreateOrderResponse({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.keyId,
    this.isCourseFree = false,
    this.receipt = '',
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return CreateOrderResponse(
      orderId: data['orderId'] as String? ?? data['id'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      keyId: data['keyId'] as String? ?? data['key'] as String? ?? '',
      isCourseFree: data['isCourseFree'] as bool? ?? false,
      receipt: data['receipt']?.toString() ?? '',
    );
  }
}

/// Result of a successful payment verification.
class VerifyPaymentResponse {
  final bool success;
  final String message;

  const VerifyPaymentResponse({
    required this.success,
    required this.message,
  });

  factory VerifyPaymentResponse.fromJson(Map<String, dynamic> json) {
    return VerifyPaymentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
    );
  }
}
