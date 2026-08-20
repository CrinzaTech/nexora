import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetCoursesByCategoryUseCase {
  final CourseRepository repository;

  GetCoursesByCategoryUseCase(this.repository);

  Future<Either<Failure, CourseCatalogResponse>> call({
    required int categoryId,
    bool? isPaid,
    int? pageNo,
  }) {
    return repository.getCatalog(
      categoryId: categoryId,
      courseType: isPaid == true ? 'Paid' : (isPaid == false ? 'Free' : null),
      pageNo: pageNo,
    );
  }
}
