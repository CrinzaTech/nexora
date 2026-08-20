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
    String? userId,
  }) = _OtpVerificationModel;

  factory OtpVerificationModel.fromJson(Map<String, dynamic> json) =>
      _$OtpVerificationModelFromJson(json);
}
