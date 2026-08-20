import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/services/device_service.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/features/auth/data/models/send_otp_response_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// v2 resend-OTP — mirrors [SendOtpV2UseCase] so the cubit can
/// dispatch a resend without re-stating the "resend == send again"
/// contract at every call site.
///
/// Like the send use-case, attaches [deviceKey] and [stdCode] to the
/// request so the backend can associate the new OTP with the device.
class ResendOtpV2UseCase {
  final OtpRepository repository;

  ResendOtpV2UseCase(this.repository);

  Future<Either<Failure, SendOtpResponseModel>> call({
    required String recipient,
    required bool isPhone,
    String? stdCode,
  }) async {
    final orgCode = OrgCodeService.instance.effectiveOrgCode;
    final deviceKey = await DeviceService.instance.getDeviceId();

    return repository.resendOtpV2(
      recipient: recipient,
      isPhone: isPhone,
      orgCode: orgCode,
      stdCode: isPhone ? stdCode : null,
      deviceKey: deviceKey,
    );
  }
}
