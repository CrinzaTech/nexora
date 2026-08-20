import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:nexora/core/storage/secure_storage.dart';

/// Provides a **stable, persistent** device identifier that never changes
/// for the lifetime of the device (survives app reinstalls, reboots, and
/// OS updates including OTA security patches).
///
/// ## Platforms
///
/// | Platform | Source identifier | Resets on |
/// |---|---|---|
/// | Android | `Settings.Secure.ANDROID_ID` (SSAID) | Factory reset only |
/// | iOS / iPadOS | `identifierForVendor` (IDFV) | Full device restore only |
///
/// ## Why not `Build.FINGERPRINT`?
///
/// `fingerprint` encodes the OS build's *incremental* segment.  Every OTA /
/// security patch changes that segment, so the string changes between updates
/// on the *same* physical device — that was the original bug.
///
/// ## Persistence layer
///
/// On the **first** call the service resolves the raw OS identifier and writes
/// it to [FlutterSecureStorage].  Every subsequent call (even across sessions)
/// reads the stored value, so the ID is permanently frozen from the first run.
///
/// ## IMPORTANT — iOS / Android safety
///
/// The `android_id` package is **Android-only**.  It is **never** imported or
/// instantiated on iOS — the `AndroidId()` object is created lazily inside
/// [_androidId], which is only called when [Platform.isAndroid] is true.
///
/// Usage:
/// ```dart
/// final id = await DeviceService.instance.getDeviceId();
/// ```
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  // ── Dependencies ──────────────────────────────────────────────────────

  // NOTE: DeviceInfoPlugin is cross-platform — safe to keep as a field.
  // AndroidId() is NOT instantiated here; it is created lazily inside
  // _androidId() so that it is never touched on iOS.
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  // The app-wide instance (encrypted prefs on Android, `first_unlock` on
  // iOS). Configuring storage options locally is what used to migrate the
  // session token out of the store [SessionService] read from — see
  // core/storage/secure_storage.dart.
  static const FlutterSecureStorage _storage = secureStorage;

  static const String _kDeviceIdKey = 'crinza_stable_device_id';

  // ── In-memory cache ────────────────────────────────────────────────────

  String? _cachedId;

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns the stable, persistent device ID.
  ///
  /// Resolution order:
  ///  1. In-memory cache  — instant, no I/O
  ///  2. [FlutterSecureStorage]  — fast single read across sessions
  ///  3. OS-level identifier  — first-ever call; stored immediately
  Future<String> getDeviceId() async {
    // 1. In-memory cache
    if (_cachedId != null) return _cachedId!;

    // 2. Previously stored value (survives app restarts)
    final stored = await _storage.read(key: _kDeviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedId = stored;
      return _cachedId!;
    }

    // 3. First-ever call — resolve from the OS and freeze in storage
    final fresh = await _resolveFromOs();
    _cachedId = fresh;
    await _storage.write(key: _kDeviceIdKey, value: fresh);
    return _cachedId!;
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Future<String> _resolveFromOs() async {
    try {
      if (Platform.isAndroid) {
        return await _androidId();
      } else if (Platform.isIOS) {
        return await _iosId();
      }
    } catch (_) {
      // OS call failed — fall through to safe default below.
    }
    return 'unknown-platform';
  }

  /// **Android only** — reads `Settings.Secure.ANDROID_ID` (SSAID).
  ///
  /// SSAID is unique per device + app-signing key.  It does NOT change on
  /// OTA updates, only on a factory reset (the device is effectively new).
  ///
  /// [AndroidId] is instantiated locally here so that the class as a whole
  /// compiles and runs correctly on iOS without touching Android-only code.
  Future<String> _androidId() async {
    // Lazy instantiation — AndroidId() is Android-only and must never be
    // called on iOS. This method is only reached when Platform.isAndroid.
    const androidIdPlugin = AndroidId();
    final ssaid = await androidIdPlugin.getId();

    if (ssaid != null && ssaid.isNotEmpty && ssaid != 'unknown') {
      return ssaid;
    }

    // Edge-case fallback (e.g. some custom ROMs with SSAID disabled).
    // Combine hardware-static segments that don't include the build number.
    final info = await _deviceInfoPlugin.androidInfo;
    return '${info.brand}-${info.model}-${info.hardware}';
  }

  /// **iOS / iPadOS** — reads `identifierForVendor` (IDFV).
  ///
  /// IDFV is stable as long as at least one app from the same vendor bundle
  /// prefix is installed on the device.  It resets only on a full device
  /// restore (equivalent of a factory reset).  Works identically on iPhone
  /// and iPad.
  Future<String> _iosId() async {
    final info = await _deviceInfoPlugin.iosInfo;
    final idfv = info.identifierForVendor;

    if (idfv != null && idfv.isNotEmpty) return idfv;

    // Fallback: model identifier + OS version (no PII, reasonably distinct).
    // e.g. "iPhone16,1-18.3.1"
    return '${info.utsname.machine}-${info.systemVersion}';
  }
}
