import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Which login affordances the current platform is allowed to offer.
///
/// Exists for one rule: App Store Review Guideline 4.8. An app that
/// offers a third-party login service must also offer an equivalent
/// privacy-preserving option — in practice, Sign in with Apple.
///
/// Crinza does not actually authenticate anyone through Google. The
/// picker reads a verified email off a device account and hands that
/// string to the app's own OTP flow, exactly as if the user had typed
/// it (see `GoogleAccountPickerService`, which signs straight back out
/// and never touches the backend). No Google credential reaches Crinza,
/// so 4.8 arguably never applies.
///
/// "Arguably" is the problem. A reviewer sees a "Continue with Google"
/// button and applies the rule to it, and the appeal costs a review
/// cycle to win. Since the email is just a string either way, iOS
/// collects it from the keyboard instead and the question never comes
/// up — which is a great deal cheaper than implementing Sign in with
/// Apple to satisfy a rule that shouldn't bind us.
abstract final class AuthPolicy {
  /// `true` where the Google account picker may be shown. Where this is
  /// `false` the same email is collected through a plain text field, so
  /// no account is ever unreachable — only the shortcut to it changes.
  static bool get allowsGoogleEmailPicker => !_isApple;

  static bool get _isApple =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}
