part of 'course_filters_cubit.dart';

@freezed
class CourseFiltersState with _$CourseFiltersState {
  const factory CourseFiltersState.initial() = _Initial;
  const factory CourseFiltersState.loading() = _Loading;
  const factory CourseFiltersState.loaded(CourseFilterData data) = _Loaded;
  const factory CourseFiltersState.error(String message) = _Error;
}
