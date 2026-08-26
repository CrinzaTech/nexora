import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexora/features/auth/domain/usecases/resend_otp_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/resend_otp_v2_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/verify_otp_v2_usecase.dart';

part 'otp_state.dart';
part 'otp_cubit.freezed.dart';

/// OTP Cubit for managing OTP verification state.
///
/// Carries both v1 (phone-only) and v2 (recipient + isPhone) flows.
/// The login page picks the v2 dispatchers; the v1 methods stay for
/// any caller that hasn't migrated and so the API surface doesn't
/// break mid-rollout.
class OtpCubit extends SafeCubit<OtpState> {
  final VerifyOtpUseCase verifyOtpUseCase;
  final ResendOtpUseCase resendOtpUseCase;
  final VerifyOtpV2UseCase verifyOtpV2UseCase;
  final ResendOtpV2UseCase resendOtpV2UseCase;

  OtpCubit({
    required this.verifyOtpUseCase,
    required this.resendOtpUseCase,
    required this.verifyOtpV2UseCase,
    required this.resendOtpV2UseCase,
  }) : super(const OtpState.initial());

  /// v1 — verify OTP via phone-only endpoint.
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    emit(const OtpState.loading());

    final result = await verifyOtpUseCase(
      phoneNumber: phoneNumber,
      otpCode: otpCode,
    );

    result.fold(
      (failure) => emit(OtpState.error(failure.message)),
      (response) => emit(
        OtpState.verified(
          token: response.token,
          refreshToken: response.refreshToken,
          userId: response.userId,
          message: response.message,
          isUserAlreadyExist: response.isUserAlreadyExist,
        ),
      ),
    );
  }

  /// v1 — resend OTP via phone-only endpoint.
  Future<void> resendOtp({required String phoneNumber}) async {
    emit(const OtpState.resending());

    final result = await resendOtpUseCase(phoneNumber: phoneNumber);

    result.fold(
      (failure) => emit(OtpState.error(failure.message)),
      (_) => emit(const OtpState.resent(status: 1, message: 'OTP resent successfully')),
    );
  }

  /// v2 — verify OTP. [isPhone] tells the backend whether [recipient]
  /// is a phone number or an email address.
  Future<void> verifyOtpV2({
    required String recipient,
    required String otpCode,
    required bool isPhone,
  }) async {
    emit(const OtpState.loading());

    final result = await verifyOtpV2UseCase(
      recipient: recipient,
      otpCode: otpCode,
      isPhone: isPhone,
    );

    result.fold(
      (failure) => emit(OtpState.error(failure.message)),
      (response) => emit(
        OtpState.verified(
          token: response.token,
          refreshToken: response.refreshToken,
          userId: response.userId,
          message: response.message,
          isUserAlreadyExist: response.isUserAlreadyExist,
        ),
      ),
    );
  }

  /// v2 — resend OTP. Same recipient semantics as [verifyOtpV2].
  Future<void> resendOtpV2({
    required String recipient,
    required bool isPhone,
  }) async {
    emit(const OtpState.resending());

    final result = await resendOtpV2UseCase(
      recipient: recipient,
      isPhone: isPhone,
    );

    result.fold(
      (failure) => emit(OtpState.error(failure.message)),
      (model) => emit(OtpState.resent(status: model.status, message: model.message)),
    );
  }

  /// Reset to initial state
  void reset() {
    emit(const OtpState.initial());
  }

  /// Reset from error to initial
  void resetFromError() {
    emit(const OtpState.initial());
  }

  /// Start/resend timer (for UI countdown)
  void startTimer() {
    emit(const OtpState.timerStarted(30));
  }

  /// Update timer value (called from UI)
  void updateTimer(int seconds) {
    emit(OtpState.timerStarted(seconds));
  }
}
