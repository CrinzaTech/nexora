import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Resolves the recording of an ended live class (course curriculum only).
/// The roomId is the curriculum node's `url`. Call on every tap — the
/// returned MP4 URL is signed and expires after a few hours.
class GetLiveClassRecordingUseCase {
  final CourseRepository repository;

  GetLiveClassRecordingUseCase(this.repository);

  Future<Either<Failure, LiveRecording>> call(String roomId) {
    return repository.getLiveClassRecording(roomId);
  }
}
