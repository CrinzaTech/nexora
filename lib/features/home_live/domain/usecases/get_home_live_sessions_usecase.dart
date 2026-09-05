import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/domain/repositories/home_live_repository.dart';

/// Course live classes for the Home rail — live first, then soonest.
class GetHomeLiveSessionsUseCase {
  final HomeLiveRepository repository;

  GetHomeLiveSessionsUseCase(this.repository);

  Future<Either<Failure, HomeLiveSessionsPage>> call({
    int pageNo = 1,
    int pageSize = 10,
  }) {
    return repository.getHomeLiveSessions(pageNo: pageNo, pageSize: pageSize);
  }
}
