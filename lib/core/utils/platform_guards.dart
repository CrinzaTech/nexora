import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Toggles the screen wakelock without letting a platform failure escape.
///
/// wakelock_plus throws `PlatformException("wakelock requires a foreground
/// activity")` when called while the app is backgrounded — a `dispose` that
/// runs after the user has switched apps, a live class ending off-screen.
/// Call sites fire these un-awaited, so the throw reached the zone and
/// Crashlytics. With no visible activity the wakelock means nothing, so
/// dropping the call is the right outcome.
void setWakelock(bool enable) {
  (enable ? WakelockPlus.enable() : WakelockPlus.disable())
      .catchError((Object _) {});
}

Future<PermissionStatus>? _micRequest;

/// Requests the microphone permission, sharing one request between callers.
///
/// permission_handler rejects a second request while one is still showing
/// (`PermissionHandler.PermissionManager: A request for permissions is
/// already running`), and a re-delivered mic grant from the hub does exactly
/// that. It also throws when there is no foreground activity. Both surface
/// here as "denied", which the callers already handle by handing the turn
/// back.
Future<PermissionStatus> requestMicPermission() {
  return _micRequest ??= Permission.microphone
      .request()
      .catchError((Object _) => PermissionStatus.denied)
      .whenComplete(() => _micRequest = null);
}
