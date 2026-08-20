import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/auth/data/models/otp_verification_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// Verify OTP use case
class VerifyOtpUseCase {
  final OtpRepository repository;

  VerifyOtpUseCase(this.repository);

  /// Execute use case
  Future<Either<Failure, OtpVerificationModel>> call({
    required String phoneNumber,
    required String otpCode,
  }) {
    final orgId = dotenv.env['ORG_ID'];
    return repository.verifyOtp(
      phoneNumber: phoneNumber,
      otpCode: otpCode,
      orgId: orgId,
    );
  }
}
