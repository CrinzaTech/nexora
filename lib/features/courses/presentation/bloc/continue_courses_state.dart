part of 'continue_courses_cubit.dart';

@freezed
class ContinueCoursesState with _$ContinueCoursesState {
  const factory ContinueCoursesState.initial() = _Initial;
  const factory ContinueCoursesState.loading() = _Loading;
  const factory ContinueCoursesState.loaded(List<CourseSummary> courses) =
      _Loaded;
  const factory ContinueCoursesState.error(String message) = _Error;
}
