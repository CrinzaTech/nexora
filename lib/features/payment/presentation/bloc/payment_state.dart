part of 'payment_cubit.dart';

@freezed
class PaymentState with _$PaymentState {
  const factory PaymentState.initial() = _Initial;
  const factory PaymentState.creatingOrder() = _CreatingOrder;
  const factory PaymentState.orderReady(CreateOrderResponse order) = _OrderReady;
  const factory PaymentState.verifying() = _Verifying;
  const factory PaymentState.paymentSuccess() = _PaymentSuccess;
  const factory PaymentState.paymentFailed(String message) = _PaymentFailed;
  const factory PaymentState.error(String message) = _Error;
}
