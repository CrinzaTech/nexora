import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nexora/core/utils/utils.dart';

/// Downloads a cover/thumbnail so it can ride along in a share sheet.
///
/// Best-effort throughout: a missing URL, a slow network or an expired
/// signature all return null, and the caller shares text only. Sharing
/// the message is the job; the picture is a bonus.
class ShareImage {
  ShareImage._();

  /// Fetches are capped: the share sheet should feel instant, and nobody
  /// waits for a thumbnail before sending a link.
  static const Duration _timeout = Duration(seconds: 6);

  /// Guards against a pathological image starving the share. Covers are
  /// small; anything past this is not worth the wait.
  static const int _maxBytes = 5 * 1024 * 1024;

  /// Downloads [url] to a temp file named after [title] (what the
  /// recipient sees in their gallery), or null if anything at all goes
  /// wrong. [fallbackName] is used when [title] slugs to nothing.
  static Future<XFile?> fetch(
    String? url, {
    required String title,
    String fallbackName = 'image',
  }) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    try {
      // A plain client, deliberately **not** the app's shared Dio.
      //
      // That instance carries AuthInterceptor, which stamps the
      // learner's Bearer token onto every request it sends. The image is
      // a presigned URL on an S3 host — sending our account token to AWS
      // would hand a third party a live credential it has no business
      // holding, and the presigned URL already carries its own
      // authorisation.
      final response = await http.get(Uri.parse(trimmed)).timeout(_timeout);

      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxBytes) return null;

      // Cache, not documents: this file exists only long enough for the
      // share sheet to read it, and the OS is welcome to reclaim it
      // afterwards.
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${_fileName(title, fallbackName, trimmed)}',
      );
      await file.writeAsBytes(bytes, flush: true);

      return XFile(file.path, mimeType: _mimeType(response, trimmed));
    } catch (e) {
      // Offline, timed out, an expired signature, no write access — all
      // of it means "share without the picture".
      Utils.debugLog('Share image skipped: $e');
      return null;
    }
  }

  /// Derived from the title rather than the S3 key, which is a hash.
  static String _fileName(String title, String fallbackName, String url) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safe = slug.isEmpty ? fallbackName : slug;
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
