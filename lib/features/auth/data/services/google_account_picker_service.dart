import 'package:google_sign_in/google_sign_in.dart';

/// What the account picker hands back: a verified email plus whatever
/// profile detail Google already exposes for free.
///
/// Name and photo come with the basic sign-in — no extra scopes, no
/// consent-screen changes, no Google verification. Phone number and
/// gender deliberately aren't here: both need *sensitive* scopes
/// (`user.phonenumbers.read` / `user.gender.read`) plus People API
/// calls, which drags the project into a much heavier review and
/// usually returns nothing anyway, since most accounts don't expose
/// them.
class GoogleAccountInfo {
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleAccountInfo({
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

/// Wraps [GoogleSignIn] to let the app pull a verified email — and the
/// name/photo that ride along with it — straight from a device Google
/// account instead of the user typing it (and risking a typo).
///
/// This intentionally does NOT authenticate the user against the app's
/// backend — it only reads the picked account's details, which the
/// caller then feeds into the normal OTP-send flow.
class GoogleAccountPickerService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  /// The most recent pick, kept so Setup Profile can prefill name and
  /// photo for a user who picked their account back on the login
  /// screen — the OTP page sits between the two, so the data can't
  /// just be passed down the widget tree.
  GoogleAccountInfo? _lastPicked;
  GoogleAccountInfo? get lastPicked => _lastPicked;

  /// Drop the cached pick once it's been consumed (or on logout), so a
  /// later signup can't inherit a previous user's name and photo.
  void clearLastPicked() => _lastPicked = null;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  /// Opens the native Google account picker and returns the picked
  /// account, or null if the user dismissed the picker.
  ///
  /// Signs out right after reading the details — we only want a
  /// one-shot lookup, not a persisted Google session — so the picker
  /// shows every account again on the next tap rather than silently
  /// reusing whichever one was picked last.
  Future<GoogleAccountInfo?> pickAccount() async {
    await _ensureInitialized();
    try {
      final account = await _googleSignIn.authenticate();
      final info = GoogleAccountInfo(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
      _lastPicked = info;
      return info;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    } finally {
      await _googleSignIn.signOut();
    }
  }
}
