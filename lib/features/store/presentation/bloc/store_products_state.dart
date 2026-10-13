part of 'store_products_cubit.dart';

@freezed
abstract class StoreProductsState with _$StoreProductsState {
  const factory StoreProductsState({
    @Default(StoreProductQuery()) StoreProductQuery query,
    @Default(<StoreProductCard>[]) List<StoreProductCard> items,
    @Default(0) int pageNo,
    @Default(0) int total,
    @Default(false) bool hasMore,

    /// First page in flight.
    @Default(false) bool loading,
    @Default(false) bool loadingMore,

    /// At least one page has answered for [query] — tells "no results"
    /// apart from "not searched yet".
    @Default(false) bool loaded,
    String? error,
  }) = _StoreProductsState;
}
