import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/profile/data/models/app_rating_url_model.dart';
import 'package:nexora/features/profile/data/models/org_info_model.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserProfileModel>> getProfile();

  Future<Either<Failure, UserProfileModel>> updateProfile({
    String? name,
    String? phoneNumber,
    String? email,
    String? dob,
    int? gender,
    File? userProfileImage,
    String? fcmToken,
  });

  /// Pushes just the device's FCM token to the dedicated
  /// `PUT /api/v1/update-fcm` endpoint (JSON body). Returns [Unit] on
  /// success — callers only care that it landed, not about any echoed
  /// payload.
  Future<Either<Failure, Unit>> updateFcmToken(String fcmToken);

  /// Fetches org-level info from `GET /api/v1/organization-info`.
  ///
  /// Exactly ONE of the three flags should be `true` per call.
  ///   [whatsappNumber]    → returns the support WhatsApp number
  ///   [termsAndCondition] → returns the T&C PDF signed URL
  ///   [refundPolicy]      → returns the Refund Policy PDF signed URL
  Future<Either<Failure, OrgInfoModel>> getOrganizationInfo({
    bool whatsappNumber = false,
    bool termsAndCondition = false,
    bool refundPolicy = false,
  });

  /// Fetches the Play Store / App Store "rate this app" URL from
  /// `GET /api/v1/UserAuth/app-rating-url`.
  ///
  /// [deviceType] must be `"android"` or `"ios"`.
  Future<Either<Failure, AppRatingUrlModel>> getAppRatingUrl(
    String deviceType,
  );
}
