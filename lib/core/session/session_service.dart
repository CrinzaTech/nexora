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
  /// Kept in sync on every [saveTokens] / [saveRenewedTokens] / [clearToken]
  /// so that synchronous
  /// callers (`token`, `isLoggedIn`) don't have to hit the platform channel.
  String? _cachedToken;

  /// In-memory mirror of the opaque refresh token.
  ///
  /// Never sent to an ordinary endpoint — only to `refresh-token` and
  /// `logout`. Null for a session created before this flow existed, or
  /// for one where the backend could not persist a refresh token; those
  /// sessions work normally but cannot renew themselves.
  String? _cachedRefreshToken;

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
    _cachedRefreshToken = await _readWithRetry(StorageKeys.refreshToken);
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

  /// Synchronous access to the cached refresh token. Null when the
  /// session cannot renew itself — see [canRenewSession].
  String? get refreshToken => _cachedRefreshToken;

  /// True when a refresh token is on hand, i.e. an expired access token
  /// can be renewed silently instead of costing the learner a new OTP.
  ///
  /// False is the pre-refresh-token behaviour: a 401 is terminal and the
  /// session is cleared. That is the correct reading for a session that
  /// never had a refresh token — there is nothing to renew with.
  bool get canRenewSession {
    final r = _cachedRefreshToken;
    return r != null && r.isNotEmpty;
  }

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

  /// Establish a session: persist the access token and its refresh token
  /// together, then refresh the cache. Called once, on successful OTP
  /// verification.
  ///
  /// [refreshToken] is nullable on purpose. The backend returns an empty
  /// one when it could not persist the token server-side, and the login
  /// still succeeds — that session simply behaves the way every session
  /// did before renewal existed. Writing the pair in one call is what
  /// makes it impossible to leave the previous learner's refresh token
  /// sitting next to the new learner's access token.
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _cachedToken = accessToken;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      _cachedRefreshToken = refreshToken;
      await _write(StorageKeys.refreshToken, refreshToken);
    } else {
      // Explicitly drop any stale refresh token rather than leaving one
      // from an earlier session paired with this brand-new access token.
      _cachedRefreshToken = null;
      await _delete(StorageKeys.refreshToken);
      debugPrint(
        'SessionService: logged in without a refresh token — this session '
        'cannot renew itself and will end when the access token expires.',
      );
    }

    await _write(StorageKeys.accessToken, accessToken);
  }

  /// Swap in the pair returned by `refresh-token`.
  ///
  /// Distinct from [saveTokens] in two ways that matter:
  ///
  ///  * The profile-complete flag is left alone — renewal is not a login,
  ///    and re-deriving that flag here would send a learner mid-session
  ///    back to the setup-profile form.
  ///  * The chat JWT is dropped. It is a *separate* token carrying its own
  ///    copy of the same expiry clock, cached indefinitely by
  ///    `ChatTokenProvider.ensureBearer`. If the access token was old
  ///    enough to need renewing, the chat token minted beside it is dead
  ///    too; clearing it makes the next chat call mint a fresh one instead
  ///    of replaying a corpse forever.
  ///
  /// The refresh token is **always** rotated by the server, so [refreshToken]
  /// here is required — writing the old one back would guarantee the next
  /// renewal trips reuse detection and revokes the family.
  Future<void> saveRenewedTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedToken = accessToken;
    _cachedRefreshToken = refreshToken;
    _cachedChatToken = null;

    // Refresh token first, deliberately. If a keystore hiccup lets only one
    // of these writes land, this is the one that has to be current: a cold
    // start holding the *retired* refresh token presents it on the next
    // renewal, the server reads that as reuse, and it revokes the entire
    // family — a logout, which is the one outcome this whole flow exists to
    // prevent. A stale access token costs a single 401 and renews.
    await _write(StorageKeys.refreshToken, refreshToken);
    await _write(StorageKeys.accessToken, accessToken);
    await _delete(StorageKeys.chatToken);
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
    // Cache is already cleared, so the next call re-mints regardless of
    // whether the delete lands.
    await _delete(StorageKeys.chatToken);
  }

  /// Remove every session token from secure storage and clear the cache.
  /// The refresh and chat tokens go with the access token — both are bound
  /// to the session that is ending.
  ///
  /// This is the *local* half of signing out. Revoking the token family
  /// server-side is `TokenRefreshService.revokeSession`, which must run
  /// **before** this (it needs the refresh token that this deletes).
  Future<void> clearToken() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedChatToken = null;
    _cachedProfileComplete = null;
    // Each delete is independent: a keystore failure on one must not skip
    // the rest and strand a token on disk that the next cold start would
    // read back as a live session.
    await _delete(StorageKeys.accessToken);
    await _delete(StorageKeys.refreshToken);
    await _delete(StorageKeys.chatToken);
    await _delete(StorageKeys.profileComplete);
  }

  /// Write that reports failure instead of throwing.
  ///
  /// The callers are past the point of no return — the server has already
  /// rotated the token, or the learner has already been signed in — so an
  /// exception here would make a successful operation look like a failed
  /// one, and the caller would act on that lie. The in-memory cache is
  /// updated before the write in every case, so the running session is
  /// correct either way; only persistence across a cold start is at risk,
  /// and that is worth a log line rather than a thrown error.
  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SessionService: secure-storage write failed for "$key" — $e');
    }
  }

  /// Delete counterpart to [_write], with the same reasoning.
  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint(
        'SessionService: secure-storage delete failed for "$key" — $e',
      );
    }
  }
}
