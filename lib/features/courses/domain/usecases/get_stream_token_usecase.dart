import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

/// Mints a StreamApi JWT for the SignalR class hub.
class GetStreamTokenUseCase {
  final CourseRepository repository;

  GetStreamTokenUseCase(this.repository);

  Future<Either<Failure, String>> call() => repository.getStreamToken();
}
