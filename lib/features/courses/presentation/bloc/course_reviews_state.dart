part of 'course_reviews_cubit.dart';

@freezed
class CourseReviewsState with _$CourseReviewsState {
  const factory CourseReviewsState.initial() = _Initial;
  const factory CourseReviewsState.loading() = _Loading;
  const factory CourseReviewsState.loaded(List<CourseReview> reviews) =
      _Loaded;
  const factory CourseReviewsState.submitting() = _Submitting;
  const factory CourseReviewsState.submitted() = _Submitted;
  const factory CourseReviewsState.error(String message) = _Error;
}
