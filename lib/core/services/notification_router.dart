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
/// response uses, so the backend can ship the same shape to both
/// channels.
class NotificationRouter {
  NotificationRouter._();

  /// Push the deep link encoded in [data]. Routes via the global
  /// [AppRouter.router] (not BuildContext) so it works for cold-start
  /// taps where no widget tree has mounted yet. Unknown types and
  /// malformed `referenceValue`s are silently dropped — never crash
  /// the app over a bad push payload.
  static Future<void> route(Map<String, dynamic> data) async {
    final type = NotificationType.fromWire(data['notificationType']);
    final ref = (data['referenceValue'] ?? '').toString().trim();
    Utils.debugLog(
      'NotificationRouter: dispatch type=${type.wireValue} ref="$ref"',
    );
    switch (type) {
      case NotificationType.course:
        final courseId = int.tryParse(ref);
        if (courseId == null) return;
        AppRouter.router.push('${AppRoutes.courseDetail}?courseId=$courseId');
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
