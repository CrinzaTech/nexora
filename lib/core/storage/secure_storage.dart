import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single [FlutterSecureStorage] configuration the whole app must use.
///
/// **Never construct `FlutterSecureStorage()` directly.** Two instances with
/// different options are not merely redundant on Android — they actively
/// destroy each other's data:
///
///   * The plugin keeps **one** native instance and re-runs
///     `ensureInitialized()` on *every* call, using whatever options that
///     particular call carried.
///   * Both option sets address the same `FlutterSecureStorage` shared-prefs
///     file and the same key prefix.
///   * A call made with `encryptedSharedPreferences: true` therefore runs
///     `checkAndMigrateToEncrypted()`, which moves **every** key in the plain
///     file into EncryptedSharedPreferences and *removes it from the plain
///     file*.
///   * A later call made with the default (`false`) reads the plain file,
///     finds nothing, and returns null.
///
/// That is exactly how the access token disappeared between launches: the
/// session was written by an instance using the defaults, then migrated out
/// from under it by [DeviceService] / [ContentCompletionService], which both
/// asked for encrypted prefs. The next cold start read null, `isLoggedIn`
/// came back false, and the splash screen sent a perfectly valid session to
/// the login page.
///
/// `first_unlock` on iOS matters for the same "token reads as missing"
/// reason: the default (`unlocked`) makes keychain items unreadable when the
/// app is cold-started before the first unlock after boot — e.g. launched by
/// a push notification.
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: false,
  ),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
