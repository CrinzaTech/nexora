class SendOtpResponseModel {
  final int status;
  final String message;

  const SendOtpResponseModel({required this.status, required this.message});

  factory SendOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return SendOtpResponseModel(
      status: (json['status'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}
