import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';

abstract class PaymentRepository {
  /// Create a Razorpay order for the `(courseId, priceId)` pair.
  /// The backend (v2) derives the chargeable amount itself so the
  /// client can't drift from the server total — there's no `amount`
  /// or `couponCode` field on the body anymore.
  Future<Either<Failure, CreateOrderResponse>> createOrder({
    required int courseId,
    required int priceId,
    String? couponCode,
  });

  Future<Either<Failure, VerifyPaymentResponse>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
}
