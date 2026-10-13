import 'package:dartz/dartz.dart' show Either;
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_cart_model.dart';
import 'package:nexora/features/store/domain/usecases/store_cart_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_cart_state.dart';
part 'store_cart_cubit.freezed.dart';

/// The learner's cart and its badge, shared by every Store screen.
///
/// A DI singleton provided above `MaterialApp`, so the badge on the store
/// home, the product page and the Discover row all read one count, and a
/// line added on the product page is already in the cart screen.
///
/// Also the app's answer to "is the Store on for this organisation?":
/// the dashboard calls [refreshCount] on start, and a 403 "The store is
/// not available." flips [StoreCartState.storeAvailable] off, which hides
/// the Discover entry point.
///
/// Every mutation redraws from the server's response (K2 answers with
/// the whole cart). Nothing here computes a price.
class StoreCartCubit extends SafeCubit<StoreCartState> {
  final GetStoreCartUseCase getCartUseCase;
  final SetStoreCartQtyUseCase setQtyUseCase;
  final RemoveFromStoreCartUseCase removeUseCase;
  final ClearStoreCartUseCase clearUseCase;
  final GetStoreCartCountUseCase getCountUseCase;

  StoreCartCubit({
    required this.getCartUseCase,
    required this.setQtyUseCase,
    required this.removeUseCase,
    required this.clearUseCase,
    required this.getCountUseCase,
  }) : super(const StoreCartState());

  /// K5. Silent: a failure keeps whatever badge is already showing.
  Future<void> refreshCount() async {
    final result = await getCountUseCase();
    result.fold((failure) {
      if (isStoreOff(failure)) emit(state.copyWith(storeAvailable: false));
    }, (count) => emit(state.copyWith(count: count, storeAvailable: true)));
  }

  /// The badge as C1 reported it.
  void syncCount(int count) =>
      emit(state.copyWith(count: count, storeAvailable: true));

  /// Any Store call answered "store not available".
  void markStoreOff() => emit(state.copyWith(storeAvailable: false));

  /// K1. [silent] keeps the current cart on screen while it refreshes.
  Future<void> load({bool silent = false}) async {
    if (!silent || state.cart == null) {
      emit(state.copyWith(loading: true, error: null));
    }
    final result = await getCartUseCase();
    result.fold(
      (failure) {
        if (isStoreOff(failure)) {
          emit(state.copyWith(loading: false, storeAvailable: false));
          return;
        }
        emit(state.copyWith(loading: false, error: storeErrorText(failure)));
      },
      (cart) => emit(
        state.copyWith(
          loading: false,
          error: null,
          cart: cart,
          count: cart.itemCount,
        ),
      ),
    );
  }

  /// K2 — sets [productId] to exactly [qty] (0 removes it).
  ///
  /// Returns null on success, or the server's refusal ("Only 2 left in
  /// stock", "at most 5 per order", …) for the caller to show.
  Future<String?> setQty(String productId, int qty) =>
      _mutate(productId, () => setQtyUseCase(productId, qty));

  /// K3.
  Future<String?> remove(String productId) =>
      _mutate(productId, () => removeUseCase(productId));

  /// K4.
  Future<String?> clear() => _mutate('*', clearUseCase.call);

  Future<String?> _mutate(
    String key,
    Future<Either<Failure, StoreCart>> Function() send,
  ) async {
    emit(state.copyWith(busy: {...state.busy, key}));
    final result = await send();
    final busy = {...state.busy}..remove(key);
    return result.fold(
      (failure) {
        emit(state.copyWith(busy: busy));
        return storeErrorText(failure);
      },
      (cart) {
        emit(state.copyWith(busy: busy, cart: cart, count: cart.itemCount));
        return null;
      },
    );
  }

  /// A paid cart order removes the bought lines server-side.
  Future<void> afterPurchase() async {
    if (state.cart != null) {
      await load(silent: true);
    } else {
      await refreshCount();
    }
  }
}
