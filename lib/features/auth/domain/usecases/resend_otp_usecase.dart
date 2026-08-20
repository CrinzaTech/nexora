import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

/// Resend OTP use case
class ResendOtpUseCase {
  final OtpRepository repository;

  ResendOtpUseCase(this.repository);

  /// Execute use case
  Future<Either<Failure, void>> call({
    required String phoneNumber,
  }) {
    return repository.resendOtp(phoneNumber: phoneNumber);
  }
}
