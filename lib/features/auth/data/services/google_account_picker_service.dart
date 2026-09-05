import 'package:google_sign_in/google_sign_in.dart';

/// Wraps [GoogleSignIn] to let the login screen pull a verified email
/// straight from a device Google account instead of the user typing one
/// by hand (and risking a typo).
///
/// This intentionally does NOT authenticate the user against the app's
/// backend — it only reads the picked account's email, which the caller
/// then feeds into the normal OTP-send flow.
class GoogleAccountPickerService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  /// Opens the native Google account picker and returns the picked
  /// account's email, or null if the user dismissed the picker.
  ///
  /// Signs out right after reading the email — we only want a one-shot
  /// email lookup, not a persisted Google session — so the picker shows
  /// every account again on the next tap rather than silently reusing
  /// whichever one was picked last.
  Future<String?> pickEmail() async {
    await _ensureInitialized();
    try {
      final account = await _googleSignIn.authenticate();
      return account.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    } finally {
      await _googleSignIn.signOut();
    }
  }
}
