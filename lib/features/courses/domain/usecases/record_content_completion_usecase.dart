import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Records that a curriculum node has been "consumed enough" to count
/// as completed (≥75% watched/read for video & PDF, fully loaded for
/// image/assignment/zip). Backed by `POST /api/v1/course/completion`.
class RecordContentCompletionUseCase {
  final CourseRepository repository;

  RecordContentCompletionUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required int coursePurchasedId,
    required String jsonContentId,
  }) {
    return repository.recordContentCompletion(
      coursePurchasedId: coursePurchasedId,
      jsonContentId: jsonContentId,
    );
  }
}
