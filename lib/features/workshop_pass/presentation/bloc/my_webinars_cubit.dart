import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/workshop_pass/data/models/my_webinar_model.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/get_my_webinars_usecase.dart';

part 'my_webinars_state.dart';
part 'my_webinars_cubit.freezed.dart';

/// Drives the My Bookings screen.
///
/// One call feeds both tabs. `upcomingCount` and `pastCount` are totals
/// across the whole history rather than this page, so the tab labels are
/// right on page one and stay right while paging.
///
/// Paging is driven by `hasMore` alone, and the **returned** `pageSize`
/// is what the next request repeats: the server clamps to 1..50, so
/// asking for more quietly gives you 50 and assuming otherwise walks the
/// page numbers off the end of the list.
class MyWebinarsCubit extends SafeCubit<MyWebinarsState> {
  final GetMyWebinarsUseCase getMyWebinarsUseCase;

  MyWebinarsCubit({required this.getMyWebinarsUseCase})
    : super(const MyWebinarsState.initial());

  static const int _pageSize = 20;

  bool _loadingMore = false;

  Future<void> load() => _fetch(showLoading: true);

  /// Refetch without flashing `loading`, for pull-to-refresh — the list
  /// stays on screen while it happens.
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const MyWebinarsState.loading());

    final result = await getMyWebinarsUseCase(
      pageNo: 1,
      pageSize: _pageSize,
    );
    if (isClosed) return;

    result.fold((failure) {
      // A silent refresh that fails leaves the list alone; a transient
      // blip should not blank a screen that is already useful.
      if (showLoading) emit(MyWebinarsState.error(failure.message));
    }, (page) => emit(MyWebinarsState.loaded(page.webinars, page)));
  }

  /// Appends the next page. Silent: the list keeps its scroll position
  /// and nothing flashes.
  Future<void> loadMore() async {
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null || !current.page.hasMore || _loadingMore) return;

    _loadingMore = true;
    final result = await getMyWebinarsUseCase(
      pageNo: current.page.pageNo + 1,
      // Read back rather than assumed: the server clamps, so this is
      // what it actually gave us last time.
      pageSize: current.page.pageSize,
    );
    _loadingMore = false;
    if (isClosed) return;

    result.fold(
      // Nothing to say for a failed *next* page: what is on screen is
      // still correct, and the next scroll retries.
      (_) {},
      (page) => emit(
        MyWebinarsState.loaded([...current.webinars, ...page.webinars], page),
      ),
    );
  }
}
