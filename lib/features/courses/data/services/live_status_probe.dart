import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:nexora/features/courses/domain/usecases/get_live_class_playback_usecase.dart';

/// What the stream server is actually doing for a room right now.
enum LiveBroadcastStatus {
  /// The HLS playlist is serving segments — the class is truly on air.
  broadcasting,

  /// The room resolved (or was refused) but no media is being produced:
  /// the host hasn't started yet, or the class was ended early.
  notBroadcasting,

  /// Never probed, or the probe failed on a network error. Callers fall
  /// back to the schedule-derived state.
  unknown,
}

/// Answers "is this live class actually broadcasting?" for curriculum
/// rows, so the LIVE NOW badge reflects reality instead of only the
/// scheduled window.
///
/// The curriculum API sends no live status — just `startDateTime` and
/// `durationSeconds` — so a class the admin ended early (or one with no
/// duration at all) would otherwise sit on "LIVE NOW" for the rest of
/// its window, or forever. The stream itself is the one source of truth
/// the app can reach: when the broadcast stops, the playlist variants
/// stop serving segments within moments.
///
/// [statusOf] is synchronous and safe to call from `build`: it returns
/// the cached verdict immediately and kicks off a background refresh
/// when the cache is stale. Listeners (the curriculum rows) are notified
/// when a verdict lands so the badge corrects itself without waiting for
/// the next periodic tick.
class LiveStatusProbe extends ChangeNotifier {
  final GetLiveClassPlaybackUseCase getPlayback;

  LiveStatusProbe(this.getPlayback);

  /// Slightly above the rows' 30s rebuild tick so each tick reuses the
  /// cache at most once before refreshing.
  static const _ttl = Duration(seconds: 45);

  /// A "not broadcasting" verdict inside the scheduled window is the one
  /// the student is waiting to see change — the host may go live any
  /// second. Re-check it faster so the tile flips to LIVE NOW within
  /// ~15s of the server saying so, instead of up to 45s + a tick.
  static const _offAirTtl = Duration(seconds: 15);

  final Map<String, _ProbeEntry> _cache = {};
  final Set<String> _inFlight = {};

  LiveBroadcastStatus statusOf(String roomId) {
    if (roomId.isEmpty) return LiveBroadcastStatus.unknown;
    final entry = _cache[roomId];
    final ttl = entry?.status == LiveBroadcastStatus.notBroadcasting
        ? _offAirTtl
        : _ttl;
    if (entry == null || DateTime.now().difference(entry.at) > ttl) {
      unawaited(_refresh(roomId));
    }
    return entry?.status ?? LiveBroadcastStatus.unknown;
  }

  Future<void> _refresh(String roomId) async {
    if (!_inFlight.add(roomId)) return;
    try {
      final result = await getPlayback(roomId);
      final status = await result.fold(
        (failure) async {
          // A definite server "no" (gone / not found / refused) means the
          // room isn't serving. Anything else — network down, 5xx — is
          // inconclusive; keep the schedule-derived badge rather than
          // flickering it off over a blip.
          final code = failure.maybeWhen(
            server: (_, statusCode) => statusCode,
            // 410 with a terminal status — definitely not on air.
            sessionStatus: (_, __) => 410,
            orElse: () => null,
          );
          return (code == 410 || code == 404 || code == 403)
              ? LiveBroadcastStatus.notBroadcasting
              : LiveBroadcastStatus.unknown;
        },
        (playback) async => await _isStreamReady(playback.hlsUrl)
            ? LiveBroadcastStatus.broadcasting
            : LiveBroadcastStatus.notBroadcasting,
      );
      _store(roomId, status);
    } catch (_) {
      _store(roomId, LiveBroadcastStatus.unknown);
    } finally {
      _inFlight.remove(roomId);
    }
  }

  void _store(String roomId, LiveBroadcastStatus status) {
    final previous = _cache[roomId]?.status;
    _cache[roomId] = _ProbeEntry(status, DateTime.now());
    if (previous != status) notifyListeners();
  }

  // ── Playlist probing ─────────────────────────────────────────────
  // Same logic as LiveClassCubit._isStreamReady: SRS writes the master
  // playlist as soon as the class exists and leaves it there after the
  // class ends — the variants (and their #EXTINF segments) are what come
  // and go, so only a real segment proves a live broadcast.

  Future<bool> _isStreamReady(String url, {int depth = 0}) async {
    if (depth > 1) return false;
    final res = await _fetchPlaylist(url);
    if (res == null) return false;
    final body = res.body;

    if (body.contains('#EXT-X-STREAM-INF')) {
      for (final variant in _variantUrls(url, body).take(3)) {
        if (await _isStreamReady(variant, depth: depth + 1)) return true;
      }
      return false;
    }
    // Segments alone don't prove a broadcast: after the educator stops,
    // the stream host keeps serving the last playlist and its window of
    // segments (200, no `#EXT-X-ENDLIST`). A playlist nobody has rewritten
    // for a few target durations is abandoned, not live — judged from the
    // server's own Last-Modified vs Date, so no client clock is involved.
    return body.contains('#EXTINF') &&
        !body.contains('#EXT-X-ENDLIST') &&
        !_isAbandoned(res, body);
  }

  bool _isAbandoned(http.Response res, String body) {
    final written = _httpDate(res.headers['last-modified']);
    final serverNow = _httpDate(res.headers['date']);
    if (written == null || serverNow == null) return false;
    final target = int.tryParse(
          RegExp(r'#EXT-X-TARGETDURATION:(\d+)').firstMatch(body)?.group(1) ??
              '',
        ) ??
        2;
    return serverNow.difference(written) >
        Duration(seconds: 3 * target.clamp(1, 10) + 3);
  }

  static DateTime? _httpDate(String? value) {
    if (value == null) return null;
    try {
      return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
          .parseUtc(value.trim());
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> _fetchPlaylist(String url) async {
    try {
      // Ask intermediaries not to serve a cached copy.
      //
      // The liveness watchdog decides the host has stopped when two reads
      // 10s apart return an identical playlist. A CDN holding the .m3u8
      // for a few seconds produces exactly that from a perfectly healthy
      // stream — a byte-identical body — and the student gets a "host
      // paused" screen while the class is still running.
      //
      // Headers only: the playback URL is signed, so a cache-busting
      // query parameter would invalidate the signature.
      final res = await http
          .get(
            Uri.parse(url),
            headers: const {
              'Cache-Control': 'no-cache, no-store, max-age=0',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      return res.body.contains('#EXTM3U') ? res : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _variantUrls(String masterUrl, String body) {
    final base = Uri.parse(masterUrl);
    final lines = body.split('\n');
    final urls = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty || candidate.startsWith('#')) continue;
        urls.add(base.resolve(candidate).toString());
        break;
      }
    }
    return urls;
  }
}

class _ProbeEntry {
  final LiveBroadcastStatus status;
  final DateTime at;

  const _ProbeEntry(this.status, this.at);
}
