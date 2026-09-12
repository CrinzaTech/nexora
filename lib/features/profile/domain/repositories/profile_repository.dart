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
    // Dial code without the leading '+' (e.g. "234" for Nigeria) for
    // the country selected alongside [phoneNumber].
    String? stdCode,
  });

  /// Files an account-deletion **request** via
  /// `DELETE /api/v1/delete-account`. [reason] is required by the API and
  /// must be non-blank.
  ///
  /// Returns [Unit] — the response carries no data, only whether the
  /// request was recorded. Nothing is deleted yet; the row is queued for
  /// back-office processing. The caller wipes local session state, and
  /// must not call this twice: the endpoint is not idempotent and a
  /// second call files a second request.
  Future<Either<Failure, Unit>> deleteAccount({required String reason});

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
  Future<Either<Failure, AppRatingUrlModel>> getAppRatingUrl(String deviceType);
}
