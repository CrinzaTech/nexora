part of 'store_order_detail_cubit.dart';

@freezed
abstract class StoreOrderDetailState with _$StoreOrderDetailState {
  const factory StoreOrderDetailState({
    StoreOrderDetail? order,
    @Default(false) bool loading,

    /// O3 / O4 / O5 in flight.
    @Default(false) bool acting,
    String? error,
  }) = _StoreOrderDetailState;
}
