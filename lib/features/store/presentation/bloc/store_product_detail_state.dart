part of 'store_product_detail_cubit.dart';

@freezed
sealed class StoreProductDetailState with _$StoreProductDetailState {
  const factory StoreProductDetailState.loading() = _Loading;
  const factory StoreProductDetailState.loaded(StoreProductDetail product) =
      _Loaded;
  const factory StoreProductDetailState.error(
    String message, {
    @Default(false) bool notFound,
  }) = _Error;
}
