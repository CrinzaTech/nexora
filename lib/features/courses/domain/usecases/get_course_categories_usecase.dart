import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetCourseCategoriesUseCase {
  final CourseRepository repository;

  GetCourseCategoriesUseCase(this.repository);

  Future<Either<Failure, CourseFilterData>> call() {
    return repository.getCourseCategories();
  }
}
