import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/security/screen_capture_guard.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/update_fcm_token_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/update_profile_usecase.dart';

part 'profile_state.dart';
part 'profile_cubit.freezed.dart';

/// Profile Cubit for managing user profile state
class ProfileCubit extends SafeCubit<ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final UpdateFcmTokenUseCase updateFcmTokenUseCase;

  ProfileCubit({
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
    required this.updateFcmTokenUseCase,
  }) : super(const ProfileState.initial());

  /// Load profile from API.
  ///
  /// Pass [force] to bypass the in-flight guard (e.g. pull-to-refresh).
  /// Without [force], a call while the cubit is already loading or
  /// updating is ignored so we don't fire duplicate requests when
  /// multiple consumers (Home + Profile) ask for it on the same frame.
  Future<void> loadProfile({bool force = false}) async {
    final inFlight = state.maybeWhen(
      loading: () => true,
      updating: (_) => true,
      orElse: () => false,
    );
    if (inFlight && !force) return;

    emit(const ProfileState.loading());

    final result = await getProfileUseCase();

    result.fold((failure) => emit(ProfileState.error(failure.message)), (
      profile,
    ) {
      _applyScreenCapturePolicy(profile);
      emit(ProfileState.loaded(profile));
    });
  }

  /// Reset back to initial — used on logout so a subsequent login doesn't
  /// see the previous user's profile. Also re-locks screen capture so a
  /// freshly logged-out app can't be screen shotted on the login screen
  /// just because the previous user happened to be allowed.
  void reset() {
    ScreenCaptureGuard.instance.setAllowed(false);
    emit(const ProfileState.initial());
  }

  /// Sync the screen-capture guard with the profile's
  /// `isScreenCaptureAllowed` flag. Called from every successful
  /// load/update so the native FLAG_SECURE (Android) / capture overlay
  /// (iOS) state always reflects the latest server decision.
  void _applyScreenCapturePolicy(UserProfileModel profile) {
    ScreenCaptureGuard.instance.setAllowed(profile.isScreenCaptureAllowed);
  }

  /// Push the cached FCM token to the backend without touching any other
  /// profile field. Called once at app startup so the server always sees
  /// the freshest token.
  ///
  /// Silent by design: never emits a state change so we don't blow away
  /// whatever the UI is currently showing (loaded/updated/etc.). Skips
  /// quietly when the user isn't logged in or when FCM hasn't surfaced a
  /// token yet (no permission, missing google-services.json, etc.).
  Future<void> syncFcmToken() async {
    final session = sl<SessionService>();
    if (!session.isLoggedIn) return;
    final token = session.fcmToken;
    if (token == null || token.isEmpty) return;

    // Dedicated lightweight endpoint — PUT /api/v1/update-fcm with a
    // JSON body, instead of round-tripping the whole multipart profile.
    final result = await updateFcmTokenUseCase(fcmToken: token);
    result.fold(
      (failure) {
        // Don't surface a state change — this is a background sync. If the
        // call failed (e.g. transient 5xx), the next app start will retry.
        if (kDebugMode) {
          debugPrint('FCM token sync failed: ${failure.message}');
        }
      },
      (_) {
        if (kDebugMode) debugPrint('FCM token synced with backend');
      },
    );
  }

  /// Update profile via API
  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? email,
    String? dob,
    int? gender,
    File? userProfileImage,
  }) async {
    final current = state.maybeWhen(
      loaded: (profile) => profile,
      updated: (profile) => profile,
      orElse: () => const UserProfileModel(),
    );
    emit(ProfileState.updating(current));

    final result = await updateProfileUseCase(
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      dob: dob,
      gender: gender,
      userProfileImage: userProfileImage,
    );

    result.fold((failure) => emit(ProfileState.error(failure.message)), (
      profile,
    ) {
      _applyScreenCapturePolicy(profile);
      emit(ProfileState.updated(profile));
    });
  }
}
