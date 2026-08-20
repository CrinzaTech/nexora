import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class SaveCourseReviewUseCase {
  final CourseRepository repository;

  SaveCourseReviewUseCase(this.repository);

  Future<Either<Failure, List<CourseReview>>> call({
    required int courseId,
    required double rating,
    required String reviewMessage,
  }) {
    return repository.saveCourseReview(
      courseId: courseId,
      rating: rating,
      reviewMessage: reviewMessage,
    );
  }
}
