import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';
import 'package:nexora/features/payment/domain/usecases/create_order_usecase.dart';
import 'package:nexora/features/payment/domain/usecases/verify_payment_usecase.dart';

part 'payment_state.dart';
part 'payment_cubit.freezed.dart';

class PaymentCubit extends SafeCubit<PaymentState> {
  final CreateOrderUseCase createOrderUseCase;
  final VerifyPaymentUseCase verifyPaymentUseCase;

  PaymentCubit({
    required this.createOrderUseCase,
    required this.verifyPaymentUseCase,
  }) : super(const PaymentState.initial());

  Future<void> createOrder({
    required int courseId,
    required int priceId,
    String? couponCode,
  }) async {
    emit(const PaymentState.creatingOrder());
    final result = await createOrderUseCase(
      courseId: courseId,
      priceId: priceId,
      couponCode: couponCode,
    );
    result.fold(
      (failure) => emit(PaymentState.error(failure.message)),
      (order) => emit(PaymentState.orderReady(order)),
    );
  }

  Future<void> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    emit(const PaymentState.verifying());
    final result = await verifyPaymentUseCase(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
    result.fold(
      (failure) => emit(PaymentState.error(failure.message)),
      (response) => response.success
          ? emit(const PaymentState.paymentSuccess())
          : emit(PaymentState.paymentFailed(response.message)),
    );
  }

  void onPaymentFailed(String message) {
    emit(PaymentState.paymentFailed(message));
  }

  void reset() => emit(const PaymentState.initial());
}
