import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/profile/data/models/app_rating_url_model.dart';
import 'package:nexora/features/profile/data/models/org_info_model.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, UserProfileModel>> getProfile() async {
    try {
      final json = await _apiClient.getUserProfile();
      return Right(UserProfileModel.fromJson(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserProfileModel>> updateProfile({
    String? name,
    String? phoneNumber,
    String? email,
    String? dob,
    int? gender,
    File? userProfileImage,
    String? fcmToken,
  }) async {
    try {
      final json = await _apiClient.updateUserProfile(
        name,
        phoneNumber,
        email,
        dob,
        _genderIntToText(gender),
        userProfileImage,
        fcmToken,
      );
      return Right(UserProfileModel.fromJson(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateFcmToken(String fcmToken) async {
    try {
      await _apiClient.updateFcmToken({'fcmToken': fcmToken});
      return const Right(unit);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Backend now expects gender as a string ("male"/"female"/"other") on
  /// `PUT /user-profile`. Existing callers still pass the legacy int
  /// (0=other, 1=male, 2=female), so map at the wire boundary.
  String? _genderIntToText(int? gender) {
    switch (gender) {
      case 1:
        return 'male';
      case 2:
        return 'female';
      case 0:
        return 'other';
      default:
        return null;
    }
  }

  @override
  Future<Either<Failure, OrgInfoModel>> getOrganizationInfo({
    bool whatsappNumber = false,
    bool termsAndCondition = false,
    bool refundPolicy = false,
  }) async {
    try {
      final json = await _apiClient.getOrganizationInfo(
        whatsappNumber: whatsappNumber,
        termsAndCondition: termsAndCondition,
        refundPolicy: refundPolicy,
      );
      return Right(OrgInfoModel.fromJson(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppRatingUrlModel>> getAppRatingUrl(
    String deviceType,
  ) async {
    try {
      final json = await _apiClient.getAppRatingUrl(deviceType: deviceType);
      print("res $json");
      return Right(AppRatingUrlModel.fromJson(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
