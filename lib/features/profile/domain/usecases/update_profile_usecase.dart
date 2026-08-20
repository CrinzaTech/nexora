import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  /// The FCM token is no longer bundled here — it has its own dedicated
  /// endpoint via [UpdateFcmTokenUseCase] / `PUT /api/v1/update-fcm`.
  /// [fcmToken] is only forwarded if a caller explicitly passes one
  /// (none currently do), so a profile edit no longer redundantly
  /// re-uploads the token in the multipart body.
  Future<Either<Failure, UserProfileModel>> call({
    String? name,
    String? phoneNumber,
    String? email,
    String? dob,
    int? gender,
    File? userProfileImage,
    String? fcmToken,
  }) {
    return repository.updateProfile(
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      dob: dob,
      gender: gender,
      userProfileImage: userProfileImage,
      fcmToken: fcmToken,
    );
  }
}
