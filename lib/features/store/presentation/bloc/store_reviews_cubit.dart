import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/usecases/store_catalog_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_reviews_state.dart';
part 'store_reviews_cubit.freezed.dart';

/// C5 — every approved review comment on a product, paged.
class StoreReviewsCubit extends SafeCubit<StoreReviewsState> {
  final GetStoreReviewsUseCase getReviewsUseCase;
  final String productId;

  StoreReviewsCubit({required this.getReviewsUseCase, required this.productId})
    : super(const StoreReviewsState());

  Future<void> load() async {
    emit(const StoreReviewsState(loading: true));
    final result = await getReviewsUseCase(productId, pageNo: 1);
    result.fold(
      (failure) => emit(StoreReviewsState(error: storeErrorText(failure))),
      (page) => emit(
        StoreReviewsState(
          items: page.items,
          pageNo: page.pageNo,
          total: page.total,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await getReviewsUseCase(productId, pageNo: state.pageNo + 1);
    result.fold((_) => emit(state.copyWith(loadingMore: false)), (page) {
      final seen = {for (final r in state.items) r.id};
      emit(
        state.copyWith(
          items: [...state.items, ...page.items.where((r) => seen.add(r.id))],
          pageNo: page.pageNo,
          total: page.total,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    });
  }
}
