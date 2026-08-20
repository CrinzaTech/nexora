import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class SaveContinueCourseUseCase {
  final CourseRepository repository;

  SaveContinueCourseUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required int courseId,
    required bool isPurchased,
  }) {
    return repository.saveContinueCourse(
      courseId: courseId,
      isPurchased: isPurchased,
    );
  }
}
