/// Verify OTP API response model
///
/// Sample response:
/// {
///   "status": "SUCCESS",
///   "isUserAlreadyExist": false,
///   "accessToken": "JWT_TOKEN_HERE",
///   "refreshToken": "OPAQUE_TOKEN_HERE",
///   "expiresIn": 604800,
///   "message": "OTP verified successfully"
/// }
class VerifyOtpResponseModel {
  final String status;
  final bool isUserAlreadyExist;
  final String accessToken;

  /// Opaque refresh token, used to renew [accessToken] without a new OTP.
  ///
  /// Empty when the backend could not persist one. That is deliberately
  /// **not** a login failure: the session still works, it just can't renew
  /// itself and ends when the access token expires — the behaviour every
  /// session had before this existed.
  final String refreshToken;

  /// Access-token lifetime in seconds. Informational on the client — the
  /// 401 is what actually drives renewal — but it is the one signal the app
  /// gets when the backend shortens that lifetime.
  final int expiresIn;

  final String message;

  const VerifyOtpResponseModel({
    required this.status,
    required this.isUserAlreadyExist,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.message,
  });

  bool get isSuccess => status == 'SUCCESS';

  /// True when this session can renew itself silently.
  bool get canRenewSession => refreshToken.isNotEmpty;

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    final rawExpiresIn = json['expiresIn'];
    return VerifyOtpResponseModel(
      status: json['status'] as String? ?? '',
      isUserAlreadyExist: json['isUserAlreadyExist'] as bool? ?? false,
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresIn: rawExpiresIn is num
          ? rawExpiresIn.toInt()
          : int.tryParse('${rawExpiresIn ?? ''}') ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}
