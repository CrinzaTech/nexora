import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/services/device_service.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/features/auth/data/models/otp_verification_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// v2 verify-OTP use case — works for both phone and email recipients.
/// Pulls `orgId` from [OrgCodeService] the same way the v1 use case does
/// so the caller doesn't have to thread it through.
///
/// Also sends the stable device identifier [DeviceService] resolves, the
/// same one **send-otp-v2** carries. Verification is where the session —
/// and with it the refresh-token family — is created, so this is the call
/// that has to say which device the family belongs to.
class VerifyOtpV2UseCase {
  final OtpRepository repository;

  VerifyOtpV2UseCase(this.repository);

  Future<Either<Failure, OtpVerificationModel>> call({
    required String recipient,
    required String otpCode,
    required bool isPhone,
  }) async {
    final orgId = OrgCodeService.instance.effectiveOrgCode;
    final deviceKey = await DeviceService.instance.getDeviceId();
    return repository.verifyOtpV2(
      recipient: recipient,
      otpCode: otpCode,
      isPhone: isPhone,
      orgId: orgId,
      deviceKey: deviceKey,
    );
  }
}
