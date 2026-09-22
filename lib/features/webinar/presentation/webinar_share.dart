import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexora/core/utils/share_image.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';

/// Passes a webinar on to someone else, with its cover art attached.
///
/// The link alone is enough to join, but a bare URL in a chat thread is
/// indistinguishable from spam. Attaching the cover makes the share look
/// like the thing it is — most messaging apps render an image + caption
/// as a card, which is what gets it opened.
///
/// The image is best-effort throughout: a missing cover, a slow network
/// or an expired signature all fall through to a text-only share rather
/// than blocking or failing it. Sharing the link is the job; the picture
/// is a bonus.
class WebinarShare {
  WebinarShare._();

  static Future<void> share({
    required BuildContext context,
    required WebinarDetail webinar,
    required String shareLink,
  }) async {
    // iPad presents the sheet as a popover anchored to the widget that
    // opened it, and throws without an origin rect.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final cover = await ShareImage.fetch(
      webinar.thumbnailUrl,
      title: webinar.title,
      fallbackName: 'webinar',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: cover == null ? null : [cover],
        subject: webinar.title,
        text: _message(webinar, shareLink),
        sharePositionOrigin: origin,
      ),
    );
  }

  static String _message(WebinarDetail webinar, String shareLink) {
    final lines = <String>[
      webinar.title,
      webinar.isLive
          ? '🔴 Live now'
          : '🗓 ${WebinarFormatting.schedule(webinar)}',
      if (webinar.educatorName != null) '👤 ${webinar.educatorName}',
      // Where it happens, and what it costs — the two things whoever
      // receives this decides on, and both of them used to be implicit
      // when every webinar was a free stream.
      if (!webinar.isStream)
        '${webinar.isInPerson ? '📍' : '💻'} ${webinar.platformName}',
      '🎟 ${WebinarFormatting.price(webinar)}',
      '',
      shareLink,
    ];
    return lines.join('\n');
  }
}
