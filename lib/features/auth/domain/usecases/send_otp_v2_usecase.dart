import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/services/device_service.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/features/auth/data/models/send_otp_response_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// v2 send-OTP use case — accepts either a phone number or an email
/// recipient and the [isPhone] discriminator the backend uses to pick
/// the delivery channel.
///
/// Reads [orgCode] from [OrgCodeService] and fetches a stable
/// hardware-level device identifier ([DeviceService]) so the backend
/// can tie the OTP delivery to a specific device.  The [stdCode]
/// (dial-code digits only, e.g. "91") is forwarded when the recipient
/// is a phone number.
///
/// Returns [SendOtpResponseModel] with both [status] and [message] so
/// callers can colour-code the snackbar (1 → green, 3 → warning,
/// anything else → red).
class SendOtpV2UseCase {
  final OtpRepository repository;

  SendOtpV2UseCase(this.repository);

  Future<Either<Failure, SendOtpResponseModel>> call({
    required String recipient,
    required bool isPhone,
    String? stdCode,
  }) async {
    final orgCode = OrgCodeService.instance.effectiveOrgCode;
    final deviceKey = await DeviceService.instance.getDeviceId();

    return repository.sendOtpV2(
      recipient: recipient,
      isPhone: isPhone,
      orgCode: orgCode,
      stdCode: isPhone ? stdCode : null,
      deviceKey: deviceKey,
    );
  }
}
