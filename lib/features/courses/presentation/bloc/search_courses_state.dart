part of 'search_courses_cubit.dart';

@freezed
class SearchCoursesState with _$SearchCoursesState {
  /// No active query — home should render its normal layout.
  const factory SearchCoursesState.idle() = _Idle;

  /// Query in flight; carry the query string so the UI can render it
  /// in the empty-results header etc.
  const factory SearchCoursesState.loading(String query) = _Loading;

  /// Results came back; carries the query so the UI can show
  /// "Results for `query`" headers.
  const factory SearchCoursesState.loaded(
    String query,
    List<CourseSummary> courses,
    bool hasMoreData,
    int currentPage,
    bool isLoadingMore,
  ) = _Loaded;

  const factory SearchCoursesState.error(String message) = _Error;
}
