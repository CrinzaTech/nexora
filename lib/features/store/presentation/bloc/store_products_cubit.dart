import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/usecases/store_catalog_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_products_state.dart';
part 'store_products_cubit.freezed.dart';

/// C3 — one filtered, sorted, infinitely scrolling product grid. Backs
/// the "All products" grid on the store home, a category, "See all" on a
/// rail, and search.
class StoreProductsCubit extends SafeCubit<StoreProductsState> {
  final GetStoreProductsUseCase getProductsUseCase;

  StoreProductsCubit({required this.getProductsUseCase})
    : super(const StoreProductsState());

  static const _pageSize = 20;

  /// Bumped on every new query so an answer to an older one — a search
  /// typed past, a sort changed mid-flight — is dropped on arrival.
  int _generation = 0;

  /// First page for [query]. Clears the grid unless [keepItems].
  Future<void> load(StoreProductQuery query, {bool keepItems = false}) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        query: query,
        items: keepItems ? state.items : const [],
        pageNo: 0,
        hasMore: false,
        loading: true,
        loadingMore: false,
        error: null,
        loaded: keepItems && state.loaded,
      ),
    );
    final result = await getProductsUseCase(
      query,
      pageNo: 1,
      pageSize: _pageSize,
    );
    if (generation != _generation) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(loading: false, error: storeErrorText(failure))),
      (page) => emit(
        state.copyWith(
          items: page.items,
          pageNo: page.pageNo,
          total: page.total,
          hasMore: page.hasMore,
          loading: false,
          loaded: true,
        ),
      ),
    );
  }

  Future<void> refresh() => load(state.query, keepItems: true);

  /// Infinite scroll: the next page while `hasMore` is true.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || state.loadingMore) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    final result = await getProductsUseCase(
      state.query,
      pageNo: state.pageNo + 1,
      pageSize: _pageSize,
    );
    if (generation != _generation) return;
    result.fold(
      // A failed next page stops the spinner; scrolling again retries.
      (_) => emit(state.copyWith(loadingMore: false)),
      (page) {
        // A product can shift pages between requests (new stock, a sort
        // by popularity); never show the same card twice.
        final seen = {for (final p in state.items) p.productId};
        emit(
          state.copyWith(
            items: [
              ...state.items,
              ...page.items.where((p) => seen.add(p.productId)),
            ],
            pageNo: page.pageNo,
            total: page.total,
            hasMore: page.hasMore,
            loadingMore: false,
          ),
        );
      },
    );
  }

  void setSort(StoreSort sort) => load(state.query.copyWith(sort: sort));

  void setPriceRange(double? min, double? max) =>
      load(state.query.copyWith(minPrice: () => min, maxPrice: () => max));

  /// Search box. Fewer than 2 letters is ignored by the API, so it just
  /// clears the grid back to the prompt.
  void search(String q) {
    final query = StoreProductQuery(
      categoryId: state.query.categoryId,
      q: q,
      sort: state.query.sort,
      minPrice: state.query.minPrice,
      maxPrice: state.query.maxPrice,
    );
    if (q.trim().length < 2) {
      _generation++;
      emit(StoreProductsState(query: query));
      return;
    }
    load(query);
  }
}
