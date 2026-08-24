import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';

/// Keeps the last successfully fetched pass for each workshop on disk.
///
/// **The pass has to open in a queue, indoors, with no signal.** Nothing
/// in the payload needs the network to render — the HTML inlines its own
/// CSS and the QR is a `data:` URI, not a URL — so the only thing
/// standing between an attendee and their ticket at a door is whether we
/// kept a copy.
///
/// Safe to show a cached pass as the real thing: the pass number and the
/// QR are **frozen server-side at first issue**, so a cached pass and a
/// freshly fetched one are the same ticket. Only the artwork can differ,
/// and only if the organiser restyled it — which is why the screen shows
/// the cached copy immediately and then replaces it if a refresh lands.
///
/// Documents rather than cache: the OS empties caches whenever it likes,
/// and the one moment this exists for is the one moment it must not be
/// missing. A pass is a few tens of KB.
///
/// Deliberately **not** the PDF. That is the save artefact and needs
/// Chromium on the server to produce; it is not the display path.
class WorkshopPassCache {
  static const String _dirName = 'workshop_passes';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// The slug reaches us from a route parameter, so it can't be trusted
  /// to stay inside the cache directory — flatten anything that would
  /// let it traverse out.
  String _fileNameFor(String slug) {
    final flat = slug
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll('..', '_')
        .trim();
    return '${flat.isEmpty ? 'pass' : flat}.json';
  }

  /// The saved pass for [slug], or null when there is none — or when the
  /// file is unreadable, which is the same thing as far as a caller is
  /// concerned.
  Future<WorkshopPass?> read(String slug) async {
    try {
      final file = File('${(await _dir()).path}/${_fileNameFor(slug)}');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return WorkshopPass.fromJson(decoded);
    } catch (e) {
      // A cache miss is never worth failing a screen over.
      Utils.debugLog('WorkshopPassCache: read failed for $slug — $e');
      return null;
    }
  }

  /// Replaces [slug]'s copy. Failures are swallowed on purpose: a pass
  /// that displays but does not cache is still a pass.
  Future<void> write(String slug, WorkshopPass pass) async {
    try {
      final file = File('${(await _dir()).path}/${_fileNameFor(slug)}');
      await file.writeAsString(jsonEncode(pass.toJson()), flush: true);
    } catch (e) {
      Utils.debugLog('WorkshopPassCache: write failed for $slug — $e');
    }
  }
}
