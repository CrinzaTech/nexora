/// Paid-webinar models — P1 (`create-order`) and P2 (`verify-payment`).
/// See WEBINAR_PAYMENT_API.md.
///
/// The one rule the shapes here enforce: **a paid webinar grants no seat
/// until the payment verifies.** Registration and payment are separate
/// steps in that order, so a learner can hold a perfectly valid token and
/// still have nothing. Only [WebinarPaymentResult.paid] says otherwise.
library;

import 'package:nexora/features/webinar/data/models/webinar_model.dart';

/// P1 — a Razorpay order, priced entirely server-side.
///
/// There is no amount in the request and none accepted from the client:
/// the server reads the final price from the database, so a tampered
/// client cannot pay a price of its own choosing.
class WebinarOrder {
  final String razorpayOrderId;

  /// Publishable key for the current environment. **Never hardcode** —
  /// test and live differ, and the backend switches them.
  final String keyId;

  /// **What goes to Razorpay.** Paise: ₹918.00 is 91800.
  final int amountPaise;

  /// Display only. Sending this to the SDK would charge ₹9.18 for a
  /// ₹918 webinar, which is exactly why the two are named apart.
  final double amountRupees;

  final String currency;

  /// Ours, not Razorpay's — the reference support needs if a payment has
  /// to be traced.
  final String receiptNo;

  final String webinarTitle;

  /// Saves the payer retyping what we already know. Any may be null.
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;

  const WebinarOrder({
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
    required this.amountRupees,
    this.currency = 'INR',
    this.receiptNo = '',
    this.webinarTitle = '',
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
  });

  factory WebinarOrder.fromJson(Map<String, dynamic> json) {
    return WebinarOrder(
      razorpayOrderId: json['razorpayOrderId'] as String? ?? '',
      keyId: json['keyId'] as String? ?? '',
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      amountRupees: (json['amountRupees'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      receiptNo: json['receiptNo']?.toString() ?? '',
      webinarTitle: json['webinarTitle'] as String? ?? '',
      prefillName: _nonEmpty(json['prefillName']),
      prefillEmail: _nonEmpty(json['prefillEmail']),
      prefillContact: _nonEmpty(json['prefillContact']),
    );
  }

  /// Enough to open the sheet with. A blank key or order id means the
  /// backend answered 200 with nothing usable — better caught here than
  /// as an opaque failure inside the SDK.
  bool get isUsable =>
      razorpayOrderId.isNotEmpty && keyId.isNotEmpty && amountPaise > 0;

  static String? _nonEmpty(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// P2 — the authoritative answer on whether money moved.
///
/// **A 200 with `paid: false` is not an error.** It is the server saying
/// the payment was not captured and nothing was charged, which is a
/// different thing from a request that failed — so this is read from
/// [paid], never from the HTTP status alone.
class WebinarPaymentResult {
  final bool paid;

  /// Written for the learner; shown as-is.
  final String message;

  /// The same payload the lobby poll returns, present only when [paid].
  /// Route on it immediately — lobby, player or venue card — with no
  /// extra call.
  final WebinarSessionState? state;

  const WebinarPaymentResult({
    required this.paid,
    required this.message,
    this.state,
  });

  factory WebinarPaymentResult.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];
    return WebinarPaymentResult(
      paid: json['paid'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      state: rawState is Map<String, dynamic>
          ? WebinarSessionState.fromJson(rawState)
          : null,
    );
  }
}
