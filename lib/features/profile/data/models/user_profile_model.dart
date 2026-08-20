/// User gender.
///
/// The backend sends this as a String. We accept the enum names
/// ("male"/"female"/"other") as well as the legacy numeric codes
/// ("1"/"2"/"0") to stay compatible with both shapes. Anything else falls
/// back to [Gender.other].
enum Gender {
  male,
  female,
  other;

  static Gender fromString(String? raw) {
    if (raw == null) return Gender.other;
    switch (raw.trim().toLowerCase()) {
      case 'male':
      case '1':
        return Gender.male;
      case 'female':
      case '2':
        return Gender.female;
      case 'other':
      case '0':
        return Gender.other;
      default:
        return Gender.other;
    }
  }
}

class UserProfileModel {
  final String? name;
  final String? phoneNumber;
  final String? email;
  final String? dob;
  final Gender? gender;
  final String? userProfileImage;
  final bool? isActive;
  final String? joinAt;

  /// Server-controlled toggle: `true` when this user is permitted to
  /// take screenshots / record the screen. `false` (or null/missing)
  /// engages [ScreenCaptureGuard] which sets Android FLAG_SECURE and
  /// blacks out the iOS window during recording.
  ///
  /// Defaults to **false** on missing — capture stays blocked unless
  /// the backend explicitly says otherwise. Loosening protection is an
  /// opt-in action, never a side-effect of a partial payload.
  final bool isScreenCaptureAllowed;

  const UserProfileModel({
    this.name,
    this.phoneNumber,
    this.email,
    this.dob,
    this.gender,
    this.userProfileImage,
    this.isActive,
    this.joinAt,
    this.isScreenCaptureAllowed = false,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return UserProfileModel(
      name: data['name'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      dob: data['dob'] as String?,
      gender: Gender.fromString(data['gender']?.toString()),
      userProfileImage: data['userProfileImage'] as String?,
      isActive: data['isActive'] as bool?,
      joinAt: data['joinAt'] as String?,
      // Read both casings — backend has historically shipped some
      // booleans as `IsThing` (PascalCase) and others as `isThing`.
      // Default to false when missing OR malformed (non-bool, e.g.
      // "true" as a string) so an unrecognised payload doesn't
      // accidentally permit capture.
      isScreenCaptureAllowed: _parseBool(
        data['isScreenCaptureAllowed'] ?? data['IsScreenCaptureAllowed'],
      ),
    );
  }
}

/// Strict boolean coercion. Accepts only real `bool` values to avoid
/// truthy-string surprises ("false" being treated as true if we just
/// did `?? false`). Anything else → `false`.
bool _parseBool(Object? v) {
  if (v is bool) return v;
  return false;
}
