part of 'store_orders_cubit.dart';

@freezed
abstract class StoreOrdersState with _$StoreOrdersState {
  const factory StoreOrdersState({
    @Default(<StoreOrderSummary>[]) List<StoreOrderSummary> items,
    @Default(0) int pageNo,
    @Default(false) bool hasMore,
    @Default(false) bool loading,
    @Default(false) bool loadingMore,
    @Default(false) bool loaded,
    String? error,
  }) = _StoreOrdersState;
}
