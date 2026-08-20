import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/webinar/data/models/webinar_payment_model.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';

/// P1 and P2 (WEBINAR_PAYMENT_API.md). Two calls with one rule between
/// them: **the order is not the purchase.** P1 only prices the thing;
/// the seat exists once P2 says `paid: true`, and never before.

/// P1 — create the Razorpay order.
class CreateWebinarOrderUseCase {
  final WebinarRepository repository;

  CreateWebinarOrderUseCase(this.repository);

  Future<Either<Failure, WebinarOrder>> call(String slug) =>
      repository.createWebinarOrder(slug);
}

/// P2 — verify, and take the seat.
class VerifyWebinarPaymentUseCase {
  final WebinarRepository repository;

  VerifyWebinarPaymentUseCase(this.repository);

  Future<Either<Failure, WebinarPaymentResult>> call(
    String slug, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) => repository.verifyWebinarPayment(
    slug,
    razorpayOrderId: razorpayOrderId,
    razorpayPaymentId: razorpayPaymentId,
    razorpaySignature: razorpaySignature,
  );
}
