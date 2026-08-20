part of 'course_detail_cubit.dart';

@freezed
class CourseDetailState with _$CourseDetailState {
  const factory CourseDetailState.initial() = _Initial;
  const factory CourseDetailState.loading() = _Loading;
  const factory CourseDetailState.loaded(Course course) = _Loaded;
  const factory CourseDetailState.error(String message) = _Error;
}
