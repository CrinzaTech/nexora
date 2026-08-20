import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:nexora/core/constants/storage_keys.dart';

/// Manages the user session: stores the JWT in the platform keystore/keychain
/// and exposes a synchronous cached getter for hot-path callers
/// (e.g. `AuthInterceptor.onRequest`).
///
/// [init] MUST be awaited once at app startup — before the service is used —
/// so the cached token is populated from secure storage.
class SessionService {
  final FlutterSecureStorage _storage;

  /// In-memory mirror of the secure-storage token.
  ///
  /// Kept in sync on every [saveToken] / [clearToken] so that synchronous
  /// callers (`token`, `isLoggedIn`) don't have to hit the platform channel.
  String? _cachedToken;

  /// In-memory mirror of the FCM token. Hot-path callers (e.g. profile
  /// update flows) read this via [fcmToken] without an async hop.
  String? _cachedFcmToken;

  /// In-memory mirror of the dedicated chat JWT (used by SignalR + the
  /// chat-group REST APIs). Distinct from [_cachedToken]; minted lazily
  /// after main login via `/api/v1/generate-token-v2`.
  String? _cachedChatToken;

  /// In-memory mirror of [StorageKeys.profileComplete]. Null means the
  /// key was never written (pre-existing session), which is treated as
  /// complete — see [isProfileComplete].
  bool? _cachedProfileComplete;

  SessionService(this._storage);

  /// Reads the persisted tokens into the in-memory cache.
  ///
  /// Call once at app startup, before the first DI resolution that reads
  /// [token] / [fcmToken] / [chatToken] synchronously.
  ///
  /// A throw here is indistinguishable from "no session" to every caller —
  /// [isLoggedIn] comes back false and the splash screen routes a perfectly
  /// valid session to the login page. The keystore/keychain occasionally
  /// refuses the very first read after a cold boot, so each read gets one
  /// retry before we accept the null.
  Future<void> init() async {
    _cachedToken = await _readWithRetry(StorageKeys.accessToken);
    _cachedFcmToken = await _readWithRetry(StorageKeys.fcmToken);
    _cachedChatToken = await _readWithRetry(StorageKeys.chatToken);
    final rawProfileComplete = await _readWithRetry(
      StorageKeys.profileComplete,
    );
    _cachedProfileComplete = rawProfileComplete == null
        ? null
        : rawProfileComplete == 'true';
  }

  /// One read, one retry, then give up and report null. Never throws — a
  /// startup that dies here would take the whole app down with it.
  Future<String?> _readWithRetry(String key) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        debugPrint(
          'SessionService: secure-storage read failed for "$key" '
          '(attempt ${attempt + 1}/2) — $e',
        );
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    }
    return null;
  }

  /// Synchronous access to the cached token. Null if not logged in OR
  /// if [init] has not yet run.
  String? get token => _cachedToken;

  /// Synchronous access to the cached FCM token. Null until [FcmService]
  /// retrieves it (or if the user denied notification permission).
  String? get fcmToken => _cachedFcmToken;

  /// Synchronous access to the cached chat JWT. Null until the first
  /// chat-feature entry-point fetches it via `/api/v1/generate-token-v2`.
  String? get chatToken => _cachedChatToken;

  /// True when a non-empty token is cached.
  bool get isLoggedIn {
    final t = _cachedToken;
    return t != null && t.isNotEmpty;
  }

  /// True unless the mandatory post-OTP profile setup form has been
  /// explicitly marked incomplete (see [saveProfileComplete]). Defaults
  /// to true when the flag was never written, so sessions created
  /// before this flag existed aren't retroactively locked out.
  bool get isProfileComplete => _cachedProfileComplete ?? true;

  /// Persist the access token to secure storage and refresh the cache.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: StorageKeys.accessToken, value: token);
  }

  /// Persist the profile-complete flag and refresh the cache. Called
  /// with `false` right after a new-user token is saved (before
  /// setup-profile is shown) and `true` once setup-profile — or an
  /// existing-user login — completes.
  Future<void> saveProfileComplete(bool value) async {
    _cachedProfileComplete = value;
    await _storage.write(
      key: StorageKeys.profileComplete,
      value: value.toString(),
    );
  }

  /// Persist the FCM token to secure storage and refresh the cache.
  Future<void> saveFcmToken(String token) async {
    _cachedFcmToken = token;
    await _storage.write(key: StorageKeys.fcmToken, value: token);
  }

  /// Persist the chat JWT to secure storage and refresh the cache.
  /// Called after a successful `/api/v1/generate-token-v2` response.
  Future<void> saveChatToken(String token) async {
    _cachedChatToken = token;
    await _storage.write(key: StorageKeys.chatToken, value: token);
  }

  /// Drop **only** the chat JWT, leaving the main session intact.
  ///
  /// The chat token expires on its own schedule and is cached forever
  /// otherwise, so a 401 from a chat call means "re-mint this", not "the
  /// user is signed out". [ChatTokenProvider.ensureBearer] mints a fresh
  /// one the next time it finds nothing cached.
  Future<void> clearChatToken() async {
    _cachedChatToken = null;
    try {
      await _storage.delete(key: StorageKeys.chatToken);
    } catch (e) {
      // Cache is already cleared, so the next call still re-mints.
      debugPrint('SessionService: chat-token delete failed — $e');
    }
  }

  /// Remove the access token from secure storage and clear the cache.
  /// Also clears the chat token since it's bound to the main session.
  Future<void> clearToken() async {
    _cachedToken = null;
    _cachedChatToken = null;
    _cachedProfileComplete = null;
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.chatToken);
    await _storage.delete(key: StorageKeys.profileComplete);
  }
}
