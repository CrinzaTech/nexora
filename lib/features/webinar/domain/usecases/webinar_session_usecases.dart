import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';

/// The five room calls (A3–A7) live in one file: they are never used
/// apart, they are all one-liners over the same repository, and a
/// separate file each would be five imports for no added clarity.

/// A3 — take the seat. The app's whole registration step.
class JoinWebinarUseCase {
  final WebinarRepository repository;

  JoinWebinarUseCase(this.repository);

  Future<Either<Failure, WebinarSessionState>> call(String slug) =>
      repository.joinWebinar(slug);
}

/// A4 — lobby poll.
class GetWebinarStateUseCase {
  final WebinarRepository repository;

  GetWebinarStateUseCase(this.repository);

  Future<Either<Failure, WebinarSessionState>> call(String slug) =>
      repository.getWebinarState(slug);
}

/// A5 — signed HLS URL. Also records attendance.
class GetWebinarPlaybackUseCase {
  final WebinarRepository repository;

  GetWebinarPlaybackUseCase(this.repository);

  Future<Either<Failure, String>> call(String slug) =>
      repository.getWebinarPlayback(slug);
}

/// A6 — chat backfill, newest first.
class GetWebinarChatUseCase {
  final WebinarRepository repository;

  GetWebinarChatUseCase(this.repository);

  Future<Either<Failure, List<LiveChatMessage>>> call(
    String slug, {
    int? beforeId,
    int limit = 30,
  }) => repository.getWebinarChat(slug, beforeId: beforeId, limit: limit);
}

/// A7 — StreamApi token for the chat socket.
class GetWebinarHubTokenUseCase {
  final WebinarRepository repository;

  GetWebinarHubTokenUseCase(this.repository);

  Future<Either<Failure, String>> call(String slug) =>
      repository.getWebinarHubToken(slug);
}
