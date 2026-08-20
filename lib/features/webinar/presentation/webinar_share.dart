import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexora/core/utils/utils.dart';
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

  /// Cover fetches are capped: the share sheet should feel instant, and
  /// nobody waits for a thumbnail before sending a link.
  static const Duration _coverTimeout = Duration(seconds: 6);

  /// Guards against a pathological image starving the share. Webinar
  /// covers are small; anything past this is not worth the wait.
  static const int _maxCoverBytes = 5 * 1024 * 1024;

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

    final cover = await _fetchCover(webinar);

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

  /// Downloads the cover to a temp file, or null if anything at all goes
  /// wrong.
  static Future<XFile?> _fetchCover(WebinarDetail webinar) async {
    final url = webinar.thumbnailUrl;
    if (url == null || url.isEmpty) return null;

    try {
      // A plain client, deliberately **not** the app's shared Dio.
      //
      // That instance carries [AuthInterceptor], which stamps the
      // learner's Bearer token onto every request it sends. The
      // thumbnail is a presigned URL on an S3 host — sending our account
      // token to AWS would hand a third party a live credential it has
      // no business holding, and the presigned URL already carries its
      // own authorisation.
      final response = await http.get(Uri.parse(url)).timeout(_coverTimeout);

      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxCoverBytes) return null;

      // Cache, not documents: this file exists only long enough for the
      // share sheet to read it, and the OS is welcome to reclaim it
      // afterwards.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_fileName(webinar, url)}');
      await file.writeAsBytes(bytes, flush: true);

      return XFile(file.path, mimeType: _mimeType(response, url));
    } catch (e) {
      // Offline, timed out, an expired signature, no write access — all
      // of it means "share the link without a picture".
      Utils.debugLog('Webinar cover share skipped: $e');
      return null;
    }
  }

  /// A name the recipient sees in their gallery. Derived from the title
  /// rather than the S3 key, which is a hash.
  static String _fileName(WebinarDetail webinar, String url) {
    final slug = webinar.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safe = slug.isEmpty ? 'webinar' : slug;
    return '${safe.substring(0, safe.length.clamp(0, 40))}${_extension(url)}';
  }

  /// The extension from the URL's *path*, ignoring the query — a
  /// presigned link ends in `…&X-Amz-Signature=…`, so the last dot in the
  /// whole string is nowhere near the filename.
  static String _extension(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    const known = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
    return known.contains(ext) ? ext : '.jpg';
  }

  static String _mimeType(http.Response response, String url) {
    final header = response.headers['content-type']?.split(';').first.trim();
    if (header != null && header.startsWith('image/')) return header;
    return switch (_extension(url)) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
