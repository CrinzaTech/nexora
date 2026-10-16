import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// What the learner sees when the org has no Free Content yet (or only a
/// draft): the API's 404 is an empty state, not an error.
const String kNoFreeContentMessage = 'No free content yet. Check back later.';

/// Discover → Free Content: the org's single Free Content, shaped like a
/// course (description, all-open content, reviews).
class GetFreeContentUseCase {
  final CourseRepository repository;

  GetFreeContentUseCase(this.repository);

  Future<Either<Failure, Course>> call() => repository.getFreeContent();
}
