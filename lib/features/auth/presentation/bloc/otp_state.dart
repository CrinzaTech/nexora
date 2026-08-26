part of 'otp_cubit.dart';

/// OTP state with Freezed pattern
@freezed
class OtpState with _$OtpState {
  /// Initial state - waiting for user input
  const factory OtpState.initial() = _Initial;

  /// Loading state - verifying OTP
  const factory OtpState.loading() = _Loading;

  /// Resending OTP state
  const factory OtpState.resending() = _Resending;

  /// OTP verified successfully
  const factory OtpState.verified({
    required String? token,

    /// Opaque refresh token for [token]. Null when the backend issued
    /// none — the session then works but cannot renew itself.
    required String? refreshToken,
    required String? userId,
    required String message,
    @Default(false) bool isUserAlreadyExist,
  }) = _Verified;

  /// OTP resent successfully — carries the server status code and message
  /// so the UI can colour the snackbar correctly.
  const factory OtpState.resent({
    required int status,
    required String message,
  }) = _Resent;

  /// Timer started with remaining seconds
  const factory OtpState.timerStarted(int secondsRemaining) = _TimerStarted;

  /// Error state
  const factory OtpState.error(String message) = _Error;
}
