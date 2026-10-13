part of 'store_cart_cubit.dart';

@freezed
abstract class StoreCartState with _$StoreCartState {
  const StoreCartState._();

  const factory StoreCartState({
    /// Null until K1 has answered once.
    StoreCart? cart,

    /// The badge. From C1, K1/K2 (`itemCount`) or K5.
    @Default(0) int count,

    /// First load of the cart screen.
    @Default(false) bool loading,

    /// Product ids with a K2/K3 in flight (`*` while clearing), so only
    /// the line being changed shows a spinner.
    @Default(<String>{}) Set<String> busy,

    /// K1 failed with nothing to show.
    String? error,

    /// False once any call answered "The store is not available."
    @Default(true) bool storeAvailable,
  }) = _StoreCartState;

  bool isBusy(String productId) =>
      busy.contains(productId) || busy.contains('*');

  int qtyOf(String productId) => cart?.qtyOf(productId) ?? 0;
}
