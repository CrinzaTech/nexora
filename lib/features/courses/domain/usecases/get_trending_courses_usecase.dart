import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetTrendingCoursesUseCase {
  final CourseRepository repository;

  GetTrendingCoursesUseCase(this.repository);

  Future<Either<Failure, CourseCatalogResponse>> call({int? pageNo}) {
    return repository.getCatalog(
      sortBy: CatalogSortBy.trending,
      pageNo: pageNo,
    );
  }
}
