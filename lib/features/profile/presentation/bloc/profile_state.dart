part of 'profile_cubit.dart';

/// Profile state with Freezed pattern
@freezed
class ProfileState with _$ProfileState {
  /// Initial state
  const factory ProfileState.initial() = _Initial;

  /// Loading state — fetching profile from API
  const factory ProfileState.loading() = _Loading;

  /// Profile loaded successfully
  const factory ProfileState.loaded(UserProfileModel profile) = _Loaded;

  /// Profile is being updated (keeps the current profile for display)
  const factory ProfileState.updating(UserProfileModel current) = _Updating;

  /// Profile updated successfully
  const factory ProfileState.updated(UserProfileModel profile) = _Updated;

  /// Error state
  const factory ProfileState.error(String message) = _Error;
}
