import 'package:nexora/core/router/app_router.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/notification/data/models/notification_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deep-link router for notification taps that originate OUTSIDE a
/// widget context — FCM banner taps (warm + cold) and tray-bridged
/// local-notification taps.
///
/// Mirrors the routing branches the in-app NotificationPage already
/// uses so a tap from the OS shade lands the user on the same screen
/// the in-app list would. Reads `notificationType` + `referenceValue`
/// from the payload — same field names the `/api/v1/notifications`
/// response uses, so the backend ships one shape to both channels.
///
/// ## Payload contract
///
/// Routing is driven entirely by the FCM **data** block (the
/// `notification` block only supplies the banner headline):
///
/// ```json
/// "data": {
///   "notificationId":   "184",
///   "notificationType": "Course",
///   "referenceValue":   "42"
/// }
/// ```
///
/// `notificationType` is the enum NAME (`None` / `Course` / `Category` /
/// `ExternalLink`), never the integer — [NotificationType.fromWire]
/// collapses anything it doesn't recognise to [NotificationType.none],
/// which opens the app but navigates nowhere. A `dispatch type=none`
/// log line means the payload is wrong, not the app.
///
/// ## Cold-start parking
///
/// [AppRouter] starts at `/splash`, and SplashScreen navigates itself
/// away ~1.3s later with `context.go(...)` — which rebuilds the match
/// list from the target location and discards imperative pushes. So a
/// tap that launched the app from terminated must NOT route on the
/// first frame: it is [park]ed instead, and the splash replays it with
/// [consumePending] once it has settled on its destination.
class NotificationRouter {
  NotificationRouter._();

  /// Deep link waiting for the splash to finish navigating. Only the
  /// most recent tap is kept — the user can only have tapped one banner
  /// to launch the app.
  static Map<String, dynamic>? _pending;

  /// Stash a cold-start payload for the splash to replay. Empty payloads
  /// (a push with no data block) are dropped rather than parked.
  static void park(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    Utils.debugLog('NotificationRouter: parking cold-start link $data');
    _pending = data;
  }

  /// Drop a parked link without routing it — used when the splash lands
  /// somewhere a deep link would be a dead end (login, setup-profile).
  static void clearPending() => _pending = null;

  /// Replay and clear whatever [park] stashed. No-op when nothing is
  /// parked, so the splash can call it unconditionally.
  static Future<void> consumePending() async {
    final data = _pending;
    _pending = null;
    if (data == null) return;
    Utils.debugLog('NotificationRouter: replaying parked cold-start link');
    await route(data);
  }

  /// Push the deep link encoded in [data]. Routes via the global
  /// [AppRouter.router] (not BuildContext) so it works from callbacks
  /// with no widget tree of their own. Unknown types and malformed
  /// `referenceValue`s are silently dropped — never crash the app over
  /// a bad push payload.
  static Future<void> route(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    final type = NotificationType.fromWire(data['notificationType']);
    final ref = (data['referenceValue'] ?? '').toString().trim();
    Utils.debugLog(
      'NotificationRouter: dispatch type=${type.wireValue} ref="$ref"',
    );
    switch (type) {
      case NotificationType.course:
        final courseId = int.tryParse(ref);
        if (courseId == null) return;
        // Land on Content, not About: a course push is almost always
        // "new content added" / "course published", so the curriculum
        // is what the user came to see. The backend can override with a
        // `tab` key (`about` / `content` / `reviews`) in the data block.
        final tab = (data['tab'] ?? 'content').toString().trim();
        AppRouter.router.push(
          '${AppRoutes.courseDetail}?courseId=$courseId'
          '&tab=${Uri.encodeComponent(tab)}',
        );
        return;
      case NotificationType.category:
        final categoryId = int.tryParse(ref);
        if (categoryId == null) return;
        // The backend doesn't ship a category title on the data payload
        // (the FCM `notification.title` is the banner headline, not the
        // route title), so fall back to whatever title field is present
        // for category routes that require it — empty is fine, the
        // course-list page falls back to the backend response's name.
        final title = (data['title'] ?? '').toString();
        AppRouter.router.push(
          '${AppRoutes.catalog}?categoryId=$categoryId'
          '&title=${Uri.encodeComponent(title)}',
        );
        return;
      case NotificationType.externalLink:
        if (ref.isEmpty) return;
        final uri = Uri.tryParse(ref);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      case NotificationType.none:
        return;
    }
  }
}
