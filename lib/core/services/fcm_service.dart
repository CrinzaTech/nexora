import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:nexora/core/services/local_notification_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/firebase_options.dart';

/// Top-level handler invoked by FCM when a message arrives while the app is
/// terminated or in the background. Must be top-level (or static) and
/// annotated with `@pragma('vm:entry-point')` so the AOT compiler keeps it
/// reachable for the background isolate.
///
/// The system auto-displays any `notification` payload in this state. A
/// `data`-only push shows nothing on its own, so this handler raises a
/// local notification for those — carrying the same payload, so a tap
/// lands on the same deep link a `notification`+`data` push would.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate has its own memory — Firebase has to be
  // reinitialized before any FlutterFire plugin can be touched.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint(
      'FCM background: id=${message.messageId} '
      'title="${message.notification?.title}" data=${message.data}',
    );
  }

  // Only for data-only sends — when a `notification` block is present the
  // OS has already drawn the banner and posting our own would double it.
  if (message.notification != null) return;
  final title = message.data['title']?.toString();
  final body = message.data['body']?.toString() ?? message.data['message']?.toString();
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
  try {
    // Fresh instance: this isolate doesn't share the one main() built.
    final notifications = LocalNotificationService();
    await notifications.init();
    await notifications.show(
      id: message.messageId.hashCode & 0x7fffffff,
      title: title?.isNotEmpty == true ? title! : 'Crinza',
      body: body ?? '',
      payload: FcmService.encodePayload(message.data),
    );
  } catch (e) {
    debugPrint('FCM background: local notification failed — $e');
  }
}

/// Owns Firebase Cloud Messaging plumbing end-to-end:
/// - permission request + device-token fetch / refresh
/// - background message handler registration
/// - foreground message → local-notification bridge (Android won't surface
///   FCM banners while the app is foregrounded; iOS only does on opt-in)
/// - tap-to-open routing for both warm-resume and cold-start
///
/// Call [init] once at app startup, after `Firebase.initializeApp()` and
/// after [SessionService.init] / [LocalNotificationService.init].
class FcmService {
  final SessionService _session;
  final LocalNotificationService _localNotifications;
  final FirebaseMessaging _messaging;

  /// Optional callback fired when the user taps a notification — payload is
  /// the FCM `data` map encoded as JSON-ish key/value pairs. The router
  /// owner can wire deep-linking through this.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Cold-start variant of [onNotificationTap], fired only for a tap that
  /// launched the app from terminated. Split out because that payload
  /// must NOT be routed on the first frame — the splash's `go()` a beat
  /// later rebuilds the match list and discards imperative pushes, so
  /// the link is parked and replayed by SplashScreen instead. Falls back
  /// to [onNotificationTap] when left unset.
  void Function(Map<String, dynamic> data)? onColdStartNotificationTap;

  FcmService(
    this._session,
    this._localNotifications, {
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Read the cached token without hitting the platform channel.
  String? get cachedToken => _session.fcmToken;

  Future<void> init() async {
    try {
      // iOS shows the system prompt; on Android (API 33+) this also handles
      // the runtime POST_NOTIFICATIONS permission.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      Utils.debugLog(
        'FcmService: permission status = ${settings.authorizationStatus}',
      );

      // iOS only — without this, FCM swallows notifications received while
      // the app is in the foreground. Android always swallows them, so we
      // bridge those through onMessage → local notifications below.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // ── Token plumbing ─────────────────────────────────────────────
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _session.saveFcmToken(token);
        _printToken('initial fetch', token);
      } else {
        Utils.debugLog('FcmService: no token returned');
      }
      _messaging.onTokenRefresh.listen((newToken) async {
        await _session.saveFcmToken(newToken);
        _printToken('refresh', newToken);
      });

      // ── Foreground messages ────────────────────────────────────────
      // Android never auto-displays FCM messages while the app is
      // foregrounded — show them ourselves so the user actually sees them.
      // iOS already handles this once the presentation options above are
      // set, but we still manually surface a local notification for parity.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Utils.debugLog(
          'FCM foreground: id=${message.messageId} data=${message.data}',
        );
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] as String?;
        final body = notification?.body ?? message.data['body'] as String?;
        if (title == null && body == null) return;
        _localNotifications.show(
          // Stable-ish id — milliseconds wraps every ~25 days, plenty for a
          // notification id slot.
          id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
          title: title ?? 'Crinza',
          body: body ?? '',
          payload: encodePayload(message.data),
        );
      });

      // ── Tap from background (warm) ─────────────────────────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        Utils.debugLog(
          'FCM tap (warm): id=${message.messageId} data=${message.data}',
        );
        onNotificationTap?.call(message.data);
      });

      // ── Tap from terminated (cold-start) ───────────────────────────
      // Defer to the post-frame callback so the GoRouter (mounted by
      // MaterialApp.router inside runApp) has actually wired up its
      // delegate before the payload is handed on. A plain
      // `Future.microtask` fires too early — main.dart calls
      // `fcmService.init()` BEFORE `runApp`, so the microtask resolved
      // against an empty router and the deep link was lost.
      //
      // This goes to [onColdStartNotificationTap], which parks the link
      // rather than routing it: at this point /splash still owns the
      // navigator and its `go(dashboard)` would wipe any push.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Utils.debugLog(
          'FCM tap (cold): id=${initialMessage.messageId} '
          'data=${initialMessage.data}',
        );
        final coldStart = onColdStartNotificationTap ?? onNotificationTap;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          coldStart?.call(initialMessage.data);
        });
      }
    } catch (e, st) {
      // Don't let a missing GoogleService-Info.plist / google-services.json
      // crash startup — just log and move on. The app stays usable; we just
      // won't have a token to send up on profile update.
      if (kDebugMode) {
        Utils.debugLog('FcmService: init failed — $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  /// Serialise the FCM data map into the string that
  /// [LocalNotificationService] hands back through its tap callback.
  ///
  /// JSON rather than `key=value&key=value`: an `externalLink` payload
  /// is a full URL and its own `?a=1&b=2` query string used to split
  /// the pair list apart, so the deep link came back mangled.
  static String encodePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    try {
      return jsonEncode(data);
    } catch (_) {
      // Non-encodable value somewhere in the map — stringify everything
      // and try once more rather than losing the deep link entirely.
      return jsonEncode(
        data.map((k, v) => MapEntry(k, v?.toString())),
      );
    }
  }

  /// Reverse of [encodePayload]. Used by the local-notification tap
  /// handler in [main] so a tap on a foreground-bridged banner reaches
  /// the same router branch an FCM background tap would.
  ///
  /// Tolerant of empty / null input, and still understands the legacy
  /// `key=value&key=value` form so a notification posted by a previous
  /// build of the app (still sitting in the tray across an update)
  /// keeps routing.
  static Map<String, dynamic> decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    if (payload.startsWith('{')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // Fall through to the legacy parser below.
      }
    }
    final out = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final i = pair.indexOf('=');
      if (i < 0) continue;
      out[pair.substring(0, i)] = pair.substring(i + 1);
    }
    return out;
  }

  /// Print the FCM token in a visually distinctive block so it can be
  /// copied straight out of `flutter logs` / IDE console and pasted
  /// into the Firebase Console "Send test message" form when debugging
  /// push delivery. [reason] differentiates the initial fetch from a
  /// later refresh in case the token rotates mid-session.
  ///
  /// `debugPrint` chunks long lines on Android — using direct
  /// multi-line debugPrint calls so the full token always lands on a
  /// single line, ready for tap-to-copy.
  void _printToken(String reason, String token) {
    debugPrint('========== FCM TOKEN ($reason) ==========');
    debugPrint(token);
    debugPrint('========================================');
  }
}
