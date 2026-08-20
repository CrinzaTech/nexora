import 'package:nexora/core/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] with the small helper API the
/// app actually needs: init, request permission, show now, schedule,
/// cancel.
///
/// Local-only — used while iOS remote push is gated on a paid Apple
/// Developer account. The same surface works on Android too.
class LocalNotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Channel id reused for every plain notification we fire. Android
  /// requires it to exist before the first show().
  static const String _defaultChannelId = 'crinza_default';
  static const String _defaultChannelName = 'General';
  static const String _defaultChannelDescription =
      'General app notifications (alerts, reminders)';

  /// Optional callback fired when the user taps a notification. The
  /// payload is whatever [show] / [schedule] passed in.
  void Function(String? payload)? onTap;

  /// Call once at startup, after [SessionService.init] but before any UI
  /// might want to schedule a notification.
  Future<void> init({void Function(String? payload)? onTap}) async {
    this.onTap = onTap;

    // Required for `zonedSchedule` — sets up the IANA tz database so we
    // can express "10am tomorrow in user's local zone" reliably.
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings(
      // Uses the Flutter launcher icon Android already ships with.
      '@mipmap/ic_launcher',
    );

    // We *don't* request permission at init — keeping that opt-in via
    // [requestPermission] so the app can pick a contextual moment to
    // prompt instead of a cold-start system dialog.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        Utils.debugLog(
          'LocalNotificationService: tap (payload=${response.payload})',
        );
        this.onTap?.call(response.payload);
      },
    );

    // Android 8+ requires the channel to exist before first show.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: _defaultChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// Asks the OS for permission. Call this from the UI when it makes
  /// sense (e.g. after onboarding, before scheduling the first reminder).
  ///
  /// Returns `true` when the user granted alerts. Throws on neither
  /// platform — failures are coerced to `false`.
  Future<bool> requestPermission() async {
    try {
      // iOS — explicit prompt.
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      // Android 13+ — runtime POST_NOTIFICATIONS permission.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true; // pre-Android-13 returns null = granted
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        Utils.debugLog('LocalNotificationService: permission failed — $e');
      }
      return false;
    }
  }

  /// Fire a notification immediately.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _defaultDetails(),
      payload: payload,
    );
  }

  /// Schedule a notification for [when]. Pass a future [DateTime] in
  /// device-local time; we'll translate to the user's IANA zone.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    final scheduledAt = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _defaultDetails(),
      payload: payload,
      // Wall-clock semantics: the user's clock at home → not absolute UTC.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  NotificationDetails _defaultDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      channelDescription: _defaultChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
