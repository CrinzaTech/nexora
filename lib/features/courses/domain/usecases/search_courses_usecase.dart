import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class SearchCoursesUseCase {
  final CourseRepository repository;

  SearchCoursesUseCase(this.repository);

  Future<Either<Failure, List<CourseSummary>>> call({
    required String query,
    bool? isPaid,
  }) async {
    final result = await repository.getCatalog(
      searchQuery: query,
      courseType: isPaid == true ? 'Paid' : (isPaid == false ? 'Free' : null),
    );
    return result.map((response) => response.courses);
  }
}
