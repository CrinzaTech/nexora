import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';

/// Repository interface for org-code validation.
abstract class OrgCodeRepository {
  /// Calls `POST /api/v1/validate-org-code` and returns whether
  /// the supplied [orgCode] is recognised by the backend.
  Future<Either<Failure, bool>> validateOrgCode({
    required String orgCode,
  });
}
