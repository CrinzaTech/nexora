part of 'my_courses_cubit.dart';

@freezed
class MyCoursesState with _$MyCoursesState {
  const factory MyCoursesState.initial() = _Initial;
  const factory MyCoursesState.loading() = _Loading;
  const factory MyCoursesState.loaded(List<CourseSummary> courses) = _Loaded;
  const factory MyCoursesState.error(String message) = _Error;
}
