import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Every poll in a live class room, shaped for this viewer. Used on
/// (re)join so an open poll is on screen without paging through chat.
class GetLiveClassPollsUseCase {
  final CourseRepository repository;

  GetLiveClassPollsUseCase(this.repository);

  Future<Either<Failure, List<LivePoll>>> call(String roomId) {
    return repository.getLiveClassPolls(roomId);
  }
}
