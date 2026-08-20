import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Resets the user's progress on a previously-completed purchase so the
/// course flips back to "in progress" with 0% completion.
///
/// Backed by `PUT /api/v1/course/{purchasedId}/re-watch`.
class RewatchCourseUseCase {
  final CourseRepository repository;

  RewatchCourseUseCase(this.repository);

  Future<Either<Failure, bool>> call({required int purchasedId}) {
    return repository.rewatchCourse(purchasedId);
  }
}
