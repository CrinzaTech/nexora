import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/auth/data/models/otp_verification_model.dart';
import 'package:nexora/features/auth/data/models/send_otp_response_model.dart';

/// OTP repository interface
abstract class OtpRepository {
  /// v1 — phone-only. Kept for backward compatibility; new code paths
  /// should use [sendOtpV2] / [verifyOtpV2] which accept email too.
  Future<Either<Failure, void>> sendOtp({
    required String mobileNumber,
  });

  /// v1 — phone-only verify.
  Future<Either<Failure, OtpVerificationModel>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? orgId,
    String? deviceKeyParam,
  });

  /// v1 — phone-only resend (just re-calls [sendOtp]).
  Future<Either<Failure, void>> resendOtp({
    required String phoneNumber,
  });

  // ── v2 — recipient-agnostic (phone OR email) ─────────────────────

  /// Sends an OTP to either an E.164 phone number or an email
  /// address. [isPhone] tells the backend which delivery channel
  /// to use. [orgCode] is the organisation identifier required by
  /// the send-otp-v2 endpoint.
  Future<Either<Failure, SendOtpResponseModel>> sendOtpV2({
    required String recipient,
    required bool isPhone,
    String? orgCode,
    String? stdCode,
    String? deviceKey,
  });

  /// Verifies an OTP for either a phone or email recipient.
  ///
  /// [deviceKey] is the stable hardware identifier, optional per the
  /// backend contract — it scopes the refresh-token family this login
  /// opens to one device.
  Future<Either<Failure, OtpVerificationModel>> verifyOtpV2({
    required String recipient,
    required String otpCode,
    required bool isPhone,
    String? orgId,
    String? deviceKey,
  });

  /// Convenience — same shape as [sendOtpV2]; lets the cubit /
  /// use case make the resend intent explicit at the call site.
  Future<Either<Failure, SendOtpResponseModel>> resendOtpV2({
    required String recipient,
    required bool isPhone,
    String? orgCode,
    String? stdCode,
    String? deviceKey,
  });
}
