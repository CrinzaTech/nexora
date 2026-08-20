import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Resolves the signed HLS playback for a live class room through the
/// student-facing stream proxy. Returns both the adaptive master URL and
/// an audio-only rendition (for weak-network / background fallback). The
/// roomId is carried by the curriculum node's `url` field.
class GetLiveClassPlaybackUseCase {
  final CourseRepository repository;

  GetLiveClassPlaybackUseCase(this.repository);

  Future<Either<Failure, LivePlayback>> call(String roomId) {
    return repository.getLiveClassPlayback(roomId);
  }
}
