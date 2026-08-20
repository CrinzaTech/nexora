import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/auth/domain/repositories/org_code_repository.dart';

/// Validate an org code against the backend.
///
/// Returns `Right(true)` when the code is accepted.
/// Returns `Left(Failure)` on network error or when `isValid` is false.
class ValidateOrgCodeUseCase {
  final OrgCodeRepository repository;

  ValidateOrgCodeUseCase(this.repository);

  Future<Either<Failure, bool>> call({required String orgCode}) {
    return repository.validateOrgCode(orgCode: orgCode);
  }
}
