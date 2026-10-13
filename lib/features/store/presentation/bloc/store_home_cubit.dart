import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/usecases/store_catalog_usecases.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_home_state.dart';
part 'store_home_cubit.freezed.dart';

/// C1 — the store's landing page.
class StoreHomeCubit extends SafeCubit<StoreHomeState> {
  final GetStoreHomeUseCase getHomeUseCase;
  final StoreCartCubit cartCubit;

  StoreHomeCubit({required this.getHomeUseCase, required this.cartCubit})
    : super(const StoreHomeState.initial());

  Future<void> load() async {
    // A pull-to-refresh keeps the page on screen instead of blanking it.
    final current = state.maybeWhen(loaded: (home) => home, orElse: () => null);
    if (current == null) emit(const StoreHomeState.loading());

    final result = await getHomeUseCase();
    result.fold(
      (failure) {
        if (isStoreOff(failure)) {
          cartCubit.markStoreOff();
          emit(const StoreHomeState.unavailable());
          return;
        }
        // Keep a page that was already showing; the caller toasts.
        if (current != null) return;
        emit(StoreHomeState.error(storeErrorText(failure)));
      },
      (home) {
        cartCubit.syncCount(home.cartCount);
        emit(StoreHomeState.loaded(home));
      },
    );
  }
}
