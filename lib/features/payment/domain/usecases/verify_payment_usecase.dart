import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';
import 'package:nexora/features/payment/domain/repositories/payment_repository.dart';

class VerifyPaymentUseCase {
  final PaymentRepository repository;

  VerifyPaymentUseCase(this.repository);

  Future<Either<Failure, VerifyPaymentResponse>> call({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return repository.verifyPayment(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }
}
