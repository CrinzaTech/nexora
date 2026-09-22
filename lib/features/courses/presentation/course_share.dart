import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/app_link_service.dart';
import 'package:nexora/core/utils/share_image.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/profile/domain/usecases/get_app_rating_url_usecase.dart';

/// Thrown when there is nothing to share at all — no course link (no org
/// known) and no store URL from the backend.
class CourseShareUnavailable implements Exception {
  const CourseShareUnavailable();
}

/// Passes a course on to someone else through the native share sheet:
/// the course cover as the picture, the course name and link as its
/// caption. The cover is best-effort — without it the share is text only.
///
/// One link does both jobs: [AppLinkService.courseLink] opens the
/// course's Content tab when the recipient has the app, and the
/// backend's page behind it forwards to the store when they don't.
///
/// Only when that link can't be built (no org known) does
/// the share fall back to the plain store URL from `app-rating-url` —
/// the same API the profile's "Share app" uses.
class CourseShare {
  CourseShare._();

  static Future<void> share({
    required BuildContext context,
    required Course course,
  }) async {
    // iPad presents the sheet as a popover anchored to the widget that
    // opened it, and throws without an origin rect.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final link =
        AppLinkService.courseLink(course.courseId)?.toString() ??
        await _storeUrl();
    if (link == null) throw const CourseShareUnavailable();

    final cover = await ShareImage.fetch(
      course.courseImageUrl,
      title: course.courseTitle,
      fallbackName: 'course',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: cover == null ? null : [cover],
        subject: course.courseTitle,
        text: _message(course, link),
        sharePositionOrigin: origin,
      ),
    );
  }

  // Share text is plain text; *asterisks* are what messaging apps
  // (WhatsApp, Telegram) render as bold.
  static String _message(Course course, String link) =>
      '*${course.courseTitle.trim()}*\n$link';

  static Future<String?> _storeUrl() async {
    final deviceType = Platform.isIOS ? 'ios' : 'android';
    try {
      final result = await sl<GetAppRatingUrlUseCase>()(deviceType);
      // Explicit type argument: without it the analyzer reads the fold
      // as returning a Future and flags an unawaited return in this try.
      return result.fold<String?>(
        (failure) {
          Utils.debugLog('Course share: store url failed — ${failure.message}');
          return null;
        },
        (info) {
          final url = info.ratingUrl?.trim();
          return url == null || url.isEmpty ? null : url;
        },
      );
    } catch (e) {
      Utils.debugLog('Course share: store url skipped — $e');
      return null;
    }
  }
}
