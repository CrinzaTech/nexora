import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Backfills live-class chat history (newest first) with pagination.
class GetLiveClassChatUseCase {
  final CourseRepository repository;

  GetLiveClassChatUseCase(this.repository);

  Future<Either<Failure, List<LiveChatMessage>>> call(
    String roomId, {
    int? beforeId,
    int? limit,
  }) {
    return repository.getLiveClassChat(
      roomId,
      beforeId: beforeId,
      limit: limit,
    );
  }
}
