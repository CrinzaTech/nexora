import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_router.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/storage/secure_storage.dart';
import 'package:nexora/core/utils/utils.dart';

/// Shareable course links — one URL that opens the course in the app when
/// it's installed, and the store when it isn't.
///
/// ## Link shape
///
///     https://<SHARE_HOST>/<org>/course/<courseId>
///     e.g. https://course-share.web.app/crinza/course/126
///
/// * **App installed** — Android App Links / iOS Universal Links hand the
///   URL straight to the app, which opens the course's Content tab.
/// * **Not installed** — the share site's page at that URL (Firebase
///   Hosting, `share_site/`) forwards to the store. On Android the Play link carries
///   `referrer=course_id=<id>`, and the first launch after install reads
///   it back ([_checkInstallReferrer]) and opens the same course.
///
/// The org segment keeps the white-label fleet apart on a shared host:
/// each client's Android manifest claims only `/<its org>/course/`, and
/// the iOS association file maps each org's paths to that org's app.
///
/// A link that arrives before there's a dashboard to push onto (cold
/// start, signed out, fresh install) is held and opened by
/// [consumePending] when the dashboard mounts — so it survives login.
///
/// Hosting half: `share_site/` and `docs/COURSE_SHARE_LINKS.md`.
class AppLinkService {
  AppLinkService._();

  static const String _defaultShareHost = 'course-share.web.app';
  static const String _referrerCheckedKey = 'install_referrer_checked';

  static StreamSubscription<Uri>? _subscription;
  static int? _pendingCourseId;

  static String get _shareHost {
    final host = dotenv.isInitialized ? dotenv.env['SHARE_HOST']?.trim() : null;
    return host == null || host.isEmpty ? _defaultShareHost : host;
  }

  /// The public link for [courseId], or null when no org is known — the
  /// caller falls back to a store-only share.
  static Uri? courseLink(int courseId) {
    final org = OrgCodeService.instance.displayOrgCode?.trim().toLowerCase();
    if (org == null || org.isEmpty) return null;
    return Uri(
      scheme: 'https',
      host: _shareHost,
      pathSegments: [org, 'course', '$courseId'],
    );
  }

  /// Course id carried by an incoming link, or null for any other shape.
  static int? courseIdFrom(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 3 || segments[1] != 'course') return null;
    return int.tryParse(segments[2]);
  }

  /// Start listening, and on Android check once whether this install came
  /// from a shared course link. `uriLinkStream` also replays the link
  /// that launched the app, so cold and warm starts share one path.
  static void init() {
    _subscription ??= AppLinks().uriLinkStream.listen(
      (uri) {
        Utils.debugLog('AppLinkService: received $uri');
        final courseId = courseIdFrom(uri);
        if (courseId != null) _open(courseId);
      },
      onError: (Object e) => Utils.debugLog('AppLinkService: stream error $e'),
    );
    unawaited(_checkInstallReferrer());
  }

  /// Opens a link held back by [_open]. Called by the dashboard when it
  /// mounts — the first point where a session is guaranteed and there's
  /// a screen to go back to from the course.
  static void consumePending() {
    final courseId = _pendingCourseId;
    _pendingCourseId = null;
    if (courseId == null) return;
    Utils.debugLog('AppLinkService: opening held course $courseId');
    _push(courseId);
  }

  /// Push now when the user is in a finished session past the splash;
  /// otherwise hold the course for [consumePending]. Pushing over the
  /// splash would be discarded by its `go()`, and over login or the
  /// mandatory setup-profile form would be a dead end.
  static void _open(int courseId) {
    final path = AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    final session = sl<SessionService>();
    final ready =
        path.isNotEmpty &&
        path != AppRoutes.splash &&
        session.isLoggedIn &&
        session.isProfileComplete;
    if (!ready) {
      Utils.debugLog('AppLinkService: holding course $courseId ($path)');
      _pendingCourseId = courseId;
      return;
    }
    _push(courseId);
  }

  static void _push(int courseId) {
    AppRouter.router.push(
      '${AppRoutes.courseDetail}?courseId=$courseId&tab=content',
    );
  }

  /// Deferred deep link for fresh Android installs: the share site's store
  /// redirect puts `course_id=<id>` in the Play `referrer`, and Play hands
  /// it back here. Checked once per install — the referrer stays readable
  /// for 90 days, and re-opening the course on every launch would be a bug.
  static Future<void> _checkInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await secureStorage.read(key: _referrerCheckedKey) != null) return;
      // Marked before the call: a device without Play services fails the
      // same way every launch, so there's nothing to gain from retrying.
      await secureStorage.write(key: _referrerCheckedKey, value: '1');
      final referrer =
          (await PlayInstallReferrer.installReferrer).installReferrer;
      Utils.debugLog('AppLinkService: install referrer "$referrer"');
      final courseId = courseIdFromReferrer(referrer);
      if (courseId != null) _open(courseId);
    } catch (e) {
      Utils.debugLog('AppLinkService: install referrer unavailable — $e');
    }
  }

  /// Reads `course_id` from a Play install referrer such as
  /// `utm_source=course_share&course_id=126`. Organic installs carry
  /// `utm_source=google-play&utm_medium=organic` and yield null.
  @visibleForTesting
  static int? courseIdFromReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty) return null;
    for (final raw in [referrer, Uri.decodeComponent(referrer)]) {
      try {
        final id = int.tryParse(Uri.splitQueryString(raw)['course_id'] ?? '');
        if (id != null) return id;
      } catch (_) {
        // Malformed encoding — try the next form.
      }
    }
    return null;
  }
}
