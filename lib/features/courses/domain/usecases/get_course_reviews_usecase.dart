import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetCourseReviewsUseCase {
  final CourseRepository repository;

  GetCourseReviewsUseCase(this.repository);

  Future<Either<Failure, List<CourseReview>>> call({required int courseId}) {
    return repository.getCourseReviews(courseId);
  }
}
