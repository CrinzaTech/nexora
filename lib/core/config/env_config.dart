/// Environment configuration for feature flags and app settings.
///
/// This class provides compile-time and runtime configuration options
/// that can be controlled via environment variables or .env files.
class EnvConfig {
  // Private constructor to prevent instantiation
  EnvConfig._();

  /// Enables or disables automatic OTP detection from SMS.
  ///
  /// When enabled, the app will attempt to automatically read OTP codes
  /// from incoming SMS messages (requires SMS_READ permission on Android).
  ///
  /// Set via environment variable: ENABLE_AUTO_OTP=true/false
  /// Defaults to `true` if not specified.
  static const bool enableAutoOtpDetect =
      bool.fromEnvironment('ENABLE_AUTO_OTP', defaultValue: true);

  /// Example additional feature flags (add as needed):
  // static const bool enableAnalytics =
  //     bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: false);
  //
  // static const bool enableCrashReporting =
  //     bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: true);
}
