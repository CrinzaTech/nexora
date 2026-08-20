import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Result of a device-integrity probe. Carries enough metadata for the
/// UI to render an honest reason for the block, instead of a generic
/// "your device is unsafe" wall.
@immutable
class DeviceSecurityVerdict {
  /// `true` when the device is in a state we won't run on in release.
  final bool isCompromised;

  /// Android: developer options enabled. iOS: always false (we use
  /// jailbreak detection as the iOS analogue instead).
  final bool developerModeEnabled;

  /// iOS: jailbroken. Android: root signals from
  /// [FlutterJailbreakDetection.jailbroken] aren't authoritative on
  /// Android (many OEM ROMs flag false-positives), so we don't drive
  /// the block off this on Android — it's reported here for telemetry
  /// only.
  final bool jailbroken;

  const DeviceSecurityVerdict({
    required this.isCompromised,
    required this.developerModeEnabled,
    required this.jailbroken,
  });

  /// Clean state — used as the starting verdict before the first probe
  /// completes, so the UI never blocks the user on a "still loading"
  /// frame.
  static const ok = DeviceSecurityVerdict(
    isCompromised: false,
    developerModeEnabled: false,
    jailbroken: false,
  );

  /// Plain-text reason shown on the block screen. Intentionally
  /// concrete so support can triage from a screenshot.
  String get blockReason {
    if (developerModeEnabled) {
      return 'Developer options are enabled on this device.\n\n'
          'For your security, this app cannot run while developer '
          'options are on. Please open Settings → System → Developer '
          'options and turn them off, then return to the app.';
    }
    if (jailbroken) {
      return 'This device appears to be jailbroken / rooted.\n\n'
          'For your security, this app cannot run on devices whose '
          'system integrity has been bypassed.';
    }
    return 'This device is in an insecure state.';
  }
}

/// Audits the device for conditions we refuse to run on in release
/// builds. Currently:
///   - Android: developer options toggle in Settings
///   - iOS:    jailbreak signal via flutter_jailbreak_detection
///
/// In debug / profile builds the audit is a no-op — we *want* to be
/// able to run on dev machines, simulators, and devices with USB
/// debugging on. The wrapper at the app root only blocks in release.
class DeviceSecurityGuard {
  DeviceSecurityGuard._();
  static final DeviceSecurityGuard instance = DeviceSecurityGuard._();

  static const MethodChannel _channel = MethodChannel('crinza/device_security');

  /// Probe the device. Always returns — failures in either probe fall
  /// back to `false` rather than throwing, so a flaky platform call
  /// can't black-screen the app.
  Future<DeviceSecurityVerdict> probe() async {
    // Skip the audit outright in debug/profile so we don't lock the
    // developer out of their own emulator.
    if (kDebugMode || kProfileMode) {
      return DeviceSecurityVerdict.ok;
    }

    final developerMode = await _checkDeveloperMode();
    final jailbroken = await _checkJailbroken();

    // Composition rule: on Android we only care about developer mode
    // (root signals are too noisy on OEM ROMs); on iOS we only care
    // about jailbreak (no developer-mode analogue we can read).
    final bool compromised;
    if (defaultTargetPlatform == TargetPlatform.android) {
      compromised = developerMode;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      compromised = jailbroken;
    } else {
      compromised = false;
    }

    return DeviceSecurityVerdict(
      isCompromised: compromised,
      developerModeEnabled: developerMode,
      jailbroken: jailbroken,
    );
  }

  Future<bool> _checkDeveloperMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final raw = await _channel.invokeMethod<bool>('isDeveloperModeEnabled');
      return raw ?? false;
    } catch (e) {
      // Channel missing / native code threw — treat as "not in dev
      // mode" so we don't lock users out on a probe failure.
      debugPrint('[DeviceSecurityGuard] dev-mode probe failed: $e');
      return false;
    }
  }

  Future<bool> _checkJailbroken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      debugPrint('[DeviceSecurityGuard] jailbreak probe failed: $e');
      return false;
    }
  }
}
