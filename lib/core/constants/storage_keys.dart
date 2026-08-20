/// Keys used for persistent storage (secure storage, shared prefs, etc.).
///
/// Centralising keys here avoids typos and makes it easy to audit everything
/// that gets written to the device.
class StorageKeys {
  StorageKeys._();

  // ============================================================
  // Auth
  // ============================================================
  static const String accessToken = 'access_token';

  /// 'true'/'false' flag for whether the mandatory post-OTP profile
  /// setup form has been completed. Written to `false` the moment a
  /// new-user token is saved (before setup-profile is shown) so the
  /// gate survives app kill / cache-clear between OTP verification
  /// and form submission. Absent (null) is treated as complete, since
  /// existing sessions created before this flag existed never wrote it.
  static const String profileComplete = 'profile_complete';

  // ============================================================
  // Appearance
  // ============================================================
  /// Persisted light/dark preference — one of `light`, `dark`, or
  /// `system`. Absent means the user has never chosen, which resolves
  /// to `system`. Deliberately NOT cleared on logout: appearance is a
  /// device preference, not session state.
  static const String themeMode = 'theme_mode';

  // ============================================================
  // Push notifications
  // ============================================================
  static const String fcmToken = 'fcm_token';

  // ============================================================
  // Chat (dedicated chat JWT for the SignalR hub + chat-group APIs).
  // Distinct from [accessToken] — minted via /api/v1/generate-token-v2
  // using the main token, then carried in the Authorization header of
  // every chat-group REST call and as the SignalR accessTokenFactory.
  // ============================================================
  static const String chatToken = 'chat_token';
}
