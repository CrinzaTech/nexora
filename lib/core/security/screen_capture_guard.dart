import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the platform-side screen-capture protection.
///
/// On Android, [setAllowed] flips Window FLAG_SECURE — when off, the OS
/// kernel itself blacks out screenshots and screen recording. On iOS,
/// the AppDelegate listens for `UIScreen.capturedDidChangeNotification`
/// and lays a full-screen black overlay on the key window while a
/// capture session is live; [setAllowed] just tells the native side
/// whether to keep doing that.
///
/// Singleton because the platform state is global (the activity window
/// is global, the iOS overlay is global) and we don't want two
/// consumers fighting over the flag.
///
/// **Secure by default**: the native side already engages protection on
/// app launch (FLAG_SECURE added in MainActivity.onCreate, iOS overlay
/// engaged on capture-status changes). [ScreenCaptureGuard.setAllowed]
/// is only ever called to *loosen* protection after the server has
/// explicitly authorised it for the current user.
class ScreenCaptureGuard {
  ScreenCaptureGuard._();
  static final ScreenCaptureGuard instance = ScreenCaptureGuard._();

  static const MethodChannel _channel = MethodChannel('crinza/screen_capture');

  /// Mirror of the last value we pushed to the native side. Lets us
  /// short-circuit redundant calls during rapid profile reloads (e.g.
  /// pull-to-refresh on the home screen).
  bool? _lastApplied;

  /// Tell the native layer whether the OS may capture this app's
  /// frames. Pass `true` only when the authenticated user's profile
  /// payload explicitly says so.
  ///
  /// No-op outside Android / iOS — desktop / web targets don't have
  /// FLAG_SECURE and we ship those as internal tools only.
  Future<void> setAllowed(bool allowed) async {
    if (_lastApplied == allowed) return;
    if (!_isSupportedPlatform) {
      _lastApplied = allowed;
      return;
    }
    try {
      await _channel.invokeMethod('setAllowed', {'allowed': allowed});
      _lastApplied = allowed;
      if (kDebugMode) {
        debugPrint('[ScreenCaptureGuard] setAllowed=$allowed');
      }
    } catch (e, st) {
      // Don't rethrow — if the native side fails we'd rather the app
      // keep working than blow up on a security toggle. The default
      // posture (blocked) was already set at activity launch, so a
      // failed loosening just leaves us in the safer state.
      debugPrint('[ScreenCaptureGuard] setAllowed FAILED: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
