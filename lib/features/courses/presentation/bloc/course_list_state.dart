part of 'course_list_cubit.dart';

@freezed
class CourseListState with _$CourseListState {
  const factory CourseListState.initial() = _Initial;
  const factory CourseListState.loading() = _Loading;
  const factory CourseListState.loaded(
    List<CourseSummary> courses, {
    @Default(true) bool hasMoreData,
    @Default(1) int currentPage,
    @Default(false) bool isLoadingMore,
  }) = _Loaded;
  const factory CourseListState.error(String message) = _Error;
}
