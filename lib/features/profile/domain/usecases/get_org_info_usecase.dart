import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/profile/data/models/org_info_model.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

/// Fetches a single category of organisation info from the
/// `GET /api/v1/organization-info` endpoint.
///
/// Exactly one flag should be `true` per call:
///   [whatsappNumber]    → support WhatsApp number
///   [termsAndCondition] → T&C PDF pre-signed URL
///   [refundPolicy]      → Refund Policy PDF pre-signed URL
class GetOrgInfoUseCase {
  final ProfileRepository _repository;

  GetOrgInfoUseCase(this._repository);

  Future<Either<Failure, OrgInfoModel>> call({
    bool whatsappNumber = false,
    bool termsAndCondition = false,
    bool refundPolicy = false,
  }) {
    return _repository.getOrganizationInfo(
      whatsappNumber: whatsappNumber,
      termsAndCondition: termsAndCondition,
      refundPolicy: refundPolicy,
    );
  }
}
