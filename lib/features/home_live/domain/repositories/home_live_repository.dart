import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';

abstract class HomeLiveRepository {
  /// Running-now + upcoming course live classes the educator allowed this
  /// learner to see. An empty page is a normal 200, not an error, and
  /// the server's ordering (live first, then soonest) is authoritative.
  Future<Either<Failure, HomeLiveSessionsPage>> getHomeLiveSessions({
    int pageNo = 1,
    int pageSize = 10,
  });
}
