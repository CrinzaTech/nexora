import 'package:freezed_annotation/freezed_annotation.dart';

part 'otp_verification_model.freezed.dart';
part 'otp_verification_model.g.dart';

/// OTP verification response model
@freezed
class OtpVerificationModel with _$OtpVerificationModel {
  const factory OtpVerificationModel({
    required bool success,
    required String message,
    @Default(false) bool isUserAlreadyExist,
    String? token,

    /// Opaque refresh token paired with [token]. Null when the backend
    /// returned an empty one — that session works but cannot renew itself.
    String? refreshToken,
    String? userId,
  }) = _OtpVerificationModel;

  factory OtpVerificationModel.fromJson(Map<String, dynamic> json) =>
      _$OtpVerificationModelFromJson(json);
}
