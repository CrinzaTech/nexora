import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/domain/usecases/store_order_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_orders_state.dart';
part 'store_orders_cubit.freezed.dart';

/// O1 — one tab of My orders.
class StoreOrdersCubit extends SafeCubit<StoreOrdersState> {
  final GetStoreOrdersUseCase getOrdersUseCase;
  final StoreOrderGroup group;

  StoreOrdersCubit({required this.getOrdersUseCase, required this.group})
    : super(const StoreOrdersState());

  Future<void> load({bool silent = false}) async {
    if (!silent || !state.loaded) {
      emit(state.copyWith(loading: true, error: null));
    }
    final result = await getOrdersUseCase(group, pageNo: 1);
    result.fold(
      (failure) => emit(
        state.copyWith(
          loading: false,
          error: silent && state.loaded ? null : storeErrorText(failure),
        ),
      ),
      (page) => emit(
        StoreOrdersState(
          items: page.items,
          pageNo: page.pageNo,
          hasMore: page.hasMore,
          loaded: true,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await getOrdersUseCase(group, pageNo: state.pageNo + 1);
    result.fold((_) => emit(state.copyWith(loadingMore: false)), (page) {
      final seen = {for (final o in state.items) o.orderNo};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            ...page.items.where((o) => seen.add(o.orderNo)),
          ],
          pageNo: page.pageNo,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    });
  }
}
