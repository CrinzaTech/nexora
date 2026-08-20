import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetMyCoursesUseCase {
  final CourseRepository repository;

  GetMyCoursesUseCase(this.repository);

  Future<Either<Failure, List<CourseSummary>>> call() {
    return repository.getMyCourses();
  }
}
