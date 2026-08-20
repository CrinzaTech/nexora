/// Verify OTP API response model
///
/// Sample response:
/// {
///   "status": "SUCCESS",
///   "isUserAlreadyExist": false,
///   "accessToken": "JWT_TOKEN_HERE",
///   "message": "OTP verified successfully"
/// }
class VerifyOtpResponseModel {
  final String status;
  final bool isUserAlreadyExist;
  final String accessToken;
  final String message;

  const VerifyOtpResponseModel({
    required this.status,
    required this.isUserAlreadyExist,
    required this.accessToken,
    required this.message,
  });

  bool get isSuccess => status == 'SUCCESS';

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponseModel(
      status: json['status'] as String? ?? '',
      isUserAlreadyExist: json['isUserAlreadyExist'] as bool? ?? false,
      accessToken: json['accessToken'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}
