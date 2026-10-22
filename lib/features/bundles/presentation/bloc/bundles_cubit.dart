import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/usecases/bundle_usecases.dart';

part 'bundles_state.dart';
part 'bundles_cubit.freezed.dart';

/// B1 — drives the Bundles rail on Home and the full "All Bundles" list.
///
/// Owned by the Dashboard for the rail, so returning to Home can refresh
/// it; the list page creates its own so paging there doesn't swell the
/// rail.
class BundlesCubit extends SafeCubit<BundlesState> {
  final GetBundlesUseCase getBundlesUseCase;

  static const int pageSize = 10;

  BundlesCubit({required this.getBundlesUseCase})
    : super(const BundlesState.initial());

  bool _isLoadingMore = false;

  Future<void> load() => _fetch(showLoading: true);

  /// Refetch without flashing `loading`, so the rail never blanks out.
  Future<void> silentRefresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const BundlesState.loading());
    final result = await getBundlesUseCase(pageNo: 1, pageSize: pageSize);
    result.fold(
      (failure) {
        // A failed silent refresh leaves what is on screen alone.
        if (showLoading) emit(BundlesState.error(failure.message));
      },
      (page) => emit(
        BundlesState.loaded(
          bundles: page.items,
          total: page.total,
          hasMore: page.hasMore,
          pageNo: page.pageNo,
        ),
      ),
    );
  }

  /// Appends the next page. Re-entrant calls are dropped, not queued.
  Future<void> loadMore() async {
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true));

    final result = await getBundlesUseCase(
      pageNo: current.pageNo + 1,
      pageSize: pageSize,
    );
    _isLoadingMore = false;

    result.fold(
      (_) => emit(current.copyWith(isLoadingMore: false)),
      (page) => emit(
        current.copyWith(
          bundles: [...current.bundles, ...page.items],
          total: page.total,
          hasMore: page.hasMore,
          pageNo: page.pageNo,
          isLoadingMore: false,
        ),
      ),
    );
  }
}
