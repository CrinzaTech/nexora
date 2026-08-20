import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/auth/data/models/otp_verification_model.dart';
import 'package:nexora/features/auth/data/models/send_otp_response_model.dart';
import 'package:nexora/features/auth/data/models/verify_otp_response_model.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';

class OtpRepositoryImpl implements OtpRepository {
  final ApiClient _apiClient;

  OtpRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, void>> sendOtp({
    required String mobileNumber,
  }) async {
    try {
      final json = await _apiClient.sendOtp(mobileNumber);
      SendOtpResponseModel.fromJson(json);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationModel>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? orgId,
    String? deviceKeyParam,
  }) async {
    try {
      final json = await _apiClient.verifyOtp(
        phoneNumber,
        otpCode,
        orgId,
        deviceKeyParam,
      );
      final response = VerifyOtpResponseModel.fromJson(json);

      if (!response.isSuccess) {
        return Left(Failure.server(message: response.message));
      }

      return Right(
        OtpVerificationModel(
          success: true,
          message: response.message,
          isUserAlreadyExist: response.isUserAlreadyExist,
          token: response.accessToken.isNotEmpty ? response.accessToken : null,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resendOtp({
    required String phoneNumber,
  }) async {
    return sendOtp(mobileNumber: phoneNumber);
  }

  // ── v2 — recipient-agnostic ───────────────────────────────────────

  @override
  Future<Either<Failure, SendOtpResponseModel>> sendOtpV2({
    required String recipient,
    required bool isPhone,
    String? orgCode,
    String? stdCode,
    String? deviceKey,
  }) async {
    try {
      final json = await _apiClient.sendOtpV2(<String, dynamic>{
        'recipient': recipient,
        'isPhone': isPhone,
        if (orgCode != null) 'orgCode': orgCode,
        if (stdCode != null) 'stdCode': stdCode,
        if (deviceKey != null) 'deviceKey': deviceKey,
      });
      final model = SendOtpResponseModel.fromJson(json);
      return Right(model);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationModel>> verifyOtpV2({
    required String recipient,
    required String otpCode,
    required bool isPhone,
    String? orgId,
  }) async {
    try {
      final json = await _apiClient.verifyOtpV2(<String, dynamic>{
        'recipient': recipient,
        'isPhone': isPhone,
        'otp': otpCode,
        if (orgId != null) 'orgId': orgId,
      });
      // v2 response shape mirrors v1 — same deserialiser.
      final response = VerifyOtpResponseModel.fromJson(json);

      if (!response.isSuccess) {
        return Left(Failure.server(message: response.message));
      }

      return Right(
        OtpVerificationModel(
          success: true,
          message: response.message,
          isUserAlreadyExist: response.isUserAlreadyExist,
          token: response.accessToken.isNotEmpty ? response.accessToken : null,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SendOtpResponseModel>> resendOtpV2({
    required String recipient,
    required bool isPhone,
    String? orgCode,
    String? stdCode,
    String? deviceKey,
  }) async {
    return sendOtpV2(
      recipient: recipient,
      isPhone: isPhone,
      orgCode: orgCode,
      stdCode: stdCode,
      deviceKey: deviceKey,
    );
  }
}
