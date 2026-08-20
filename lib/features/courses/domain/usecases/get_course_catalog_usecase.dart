import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetCourseCatalogUseCase {
  final CourseRepository repository;

  GetCourseCatalogUseCase(this.repository);

  Future<Either<Failure, CourseCatalogResponse>> call({
    int? pageNo,
    String? searchQuery,
    String? courseType,
    int? categoryId,
    int? tileId,
    int? courseStatusType,
    CatalogSortBy? sortBy,
  }) {
    return repository.getCatalog(
      pageNo: pageNo,
      searchQuery: searchQuery,
      courseType: courseType,
      categoryId: categoryId,
      tileId: tileId,
      courseStatusType: courseStatusType,
      sortBy: sortBy,
    );
  }
}
