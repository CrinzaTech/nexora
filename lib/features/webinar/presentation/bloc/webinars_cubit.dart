import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/usecases/get_webinars_usecase.dart';

part 'webinars_state.dart';
part 'webinars_cubit.freezed.dart';

/// Drives the Webinars rail on Home and the full "All Webinars" list.
///
/// Owned by the Dashboard alongside [HomeCubit] so re-entering the Home
/// tab can refresh it — a webinar going live is exactly the kind of
/// change a learner expects to see without restarting the app.
class WebinarsCubit extends SafeCubit<WebinarsState> {
  final GetWebinarsUseCase getWebinarsUseCase;

  /// The rail shows the first page only; the list page appends from
  /// here. Kept at the doc's default (the server clamps to 50 anyway).
  static const int pageSize = 10;

  WebinarsCubit({required this.getWebinarsUseCase})
    : super(const WebinarsState.initial());

  bool _isLoadingMore = false;

  Future<void> load() => _fetch(showLoading: true);

  /// Refetch without flashing `loading`, so the rail never blanks out
  /// under the user while they are looking at it.
  Future<void> silentRefresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const WebinarsState.loading());
    final result = await getWebinarsUseCase(pageNo: 1, pageSize: pageSize);
    result.fold(
      (failure) {
        // A silent refresh that fails leaves the current list alone — a
        // transient blip shouldn't empty a section the learner can see.
        if (showLoading) emit(WebinarsState.error(failure.message));
      },
      (page) => emit(
        WebinarsState.loaded(
          webinars: page.webinars,
          liveCount: page.liveCount,
          total: page.total,
          hasMore: page.hasMore,
          pageNo: page.pageNo,
        ),
      ),
    );
  }

  /// Appends the next page. No-op unless the current state is `loaded`
  /// with more to fetch, and re-entrant calls (a fast scroll firing the
  /// threshold twice) are dropped rather than queued.
  Future<void> loadMore() async {
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true));

    final result = await getWebinarsUseCase(
      pageNo: current.pageNo + 1,
      pageSize: pageSize,
    );
    _isLoadingMore = false;

    result.fold(
      // Keep what's on screen; the footer spinner just goes away. The
      // next scroll to the bottom retries.
      (_) => emit(current.copyWith(isLoadingMore: false)),
      (page) => emit(
        current.copyWith(
          webinars: [...current.webinars, ...page.webinars],
          liveCount: page.liveCount,
          total: page.total,
          hasMore: page.hasMore,
          pageNo: page.pageNo,
          isLoadingMore: false,
        ),
      ),
    );
  }

  void reset() => emit(const WebinarsState.initial());
}
