import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_reviews_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/save_course_review_usecase.dart';

part 'course_reviews_state.dart';
part 'course_reviews_cubit.freezed.dart';

class CourseReviewsCubit extends SafeCubit<CourseReviewsState> {
  final GetCourseReviewsUseCase getCourseReviewsUseCase;
  final SaveCourseReviewUseCase saveCourseReviewUseCase;

  CourseReviewsCubit({
    required this.getCourseReviewsUseCase,
    required this.saveCourseReviewUseCase,
  }) : super(const CourseReviewsState.initial());

  Future<void> load(int courseId) async {
    emit(const CourseReviewsState.loading());
    final result = await getCourseReviewsUseCase(courseId: courseId);
    result.fold(
      (failure) => emit(CourseReviewsState.error(failure.message)),
      (reviews) => emit(CourseReviewsState.loaded(reviews)),
    );
  }

  /// Submits a new review and emits a [submitted] event so the UI can show a
  /// confirmation. The state then transitions back to [loaded] with the
  /// fresh list returned by the API.
  Future<void> submit({
    required int courseId,
    required double rating,
    required String reviewMessage,
  }) async {
    emit(const CourseReviewsState.submitting());
    final result = await saveCourseReviewUseCase(
      courseId: courseId,
      rating: rating,
      reviewMessage: reviewMessage,
    );
    result.fold(
      (failure) => emit(CourseReviewsState.error(failure.message)),
      (reviews) {
        emit(const CourseReviewsState.submitted());
        emit(CourseReviewsState.loaded(reviews));
      },
    );
  }
}
