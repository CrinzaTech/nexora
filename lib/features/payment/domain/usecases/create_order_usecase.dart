import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';
import 'package:nexora/features/payment/domain/repositories/payment_repository.dart';

class CreateOrderUseCase {
  final PaymentRepository repository;

  CreateOrderUseCase(this.repository);

  Future<Either<Failure, CreateOrderResponse>> call({
    required int courseId,
    required int priceId,
    String? couponCode,
  }) {
    return repository.createOrder(
      courseId: courseId,
      priceId: priceId,
      couponCode: couponCode,
    );
  }
}
