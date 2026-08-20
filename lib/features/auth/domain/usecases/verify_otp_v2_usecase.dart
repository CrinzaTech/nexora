import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/features/auth/data/models/otp_verification_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// v2 verify-OTP use case — works for both phone and email recipients.
/// Pulls `orgId` from [OrgCodeService] the same way the v1 use case does
/// so the caller doesn't have to thread it through.
///
/// Note: `deviceKey` is intentionally NOT sent here. It is attached to
/// the **send-otp-v2** request instead, as per the backend contract.
class VerifyOtpV2UseCase {
  final OtpRepository repository;

  VerifyOtpV2UseCase(this.repository);

  Future<Either<Failure, OtpVerificationModel>> call({
    required String recipient,
    required String otpCode,
    required bool isPhone,
  }) {
    final orgId = OrgCodeService.instance.effectiveOrgCode;
    return repository.verifyOtpV2(
      recipient: recipient,
      otpCode: otpCode,
      isPhone: isPhone,
      orgId: orgId,
    );
  }
}
