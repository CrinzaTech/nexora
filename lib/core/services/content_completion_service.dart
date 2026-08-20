import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/storage/secure_storage.dart';
import 'package:nexora/features/courses/domain/usecases/record_content_completion_usecase.dart';

/// How a single POST attempt ended — drives what the queue does next.
enum _Attempt {
  /// Server accepted it (or said "already reached"). Drop from the queue.
  delivered,

  /// No usable connection. Stop the whole flush; everything behind it
  /// would fail the same way.
  offline,

  /// Transient server-side problem (5xx / 429 / auth expiry). Keep and
  /// retry later, but move on to the next entry now.
  retryable,

  /// The server rejected this specific completion and always will
  /// (400 / 404 / 422 — deleted node, revoked purchase). Drop it, or it
  /// blocks the queue forever.
  permanent,
}

/// One queued completion plus how many times we've tried to deliver it.
class _Pending {
  final int coursePurchasedId;
  final String jsonContentId;
  int attempts;

  _Pending(this.coursePurchasedId, this.jsonContentId, {this.attempts = 0});

  Map<String, dynamic> toJson() => {
    'c': coursePurchasedId,
    'n': jsonContentId,
    'a': attempts,
  };

  static _Pending? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final c = (raw['c'] as num?)?.toInt();
    final n = raw['n']?.toString();
    if (c == null || c == 0 || n == null || n.isEmpty) return null;
    return _Pending(c, n, attempts: (raw['a'] as num?)?.toInt() ?? 0);
  }
}

/// Centralised completion tracker for curriculum nodes.
///
/// Every viewer calls [markCompleted] when its type-specific trigger
/// fires:
///
///   | Node type          | Trigger                                   |
///   |--------------------|-------------------------------------------|
///   | video / youtube    | playback position clears 75%              |
///   | document (any)     | viewer opened                             |
///   | image / zip        | opened / tapped                           |
///   | live class         | room joined (waiting *or* live phase)     |
///   | assignment         | opened, and again on successful submit     |
///   | exam               | opened, and again on attempt start        |
///
/// ## Delivery guarantee
///
/// A completion must never be lost — a student who clears the bar while
/// offline, or during a 5xx blip, or who swipes the app away the instant
/// the trigger fires, still gets credit. The queue is therefore a
/// **write-ahead log**:
///
///  1. the key is persisted to [FlutterSecureStorage] *before* the POST
///     is attempted, so process death mid-request can't lose it;
///  2. the POST runs; on success the key is removed from the queue and
///     remembered in `_marked` so it never fires again this session;
///  3. on failure the key stays queued and is retried on the next app
///     launch ([init]) and on every connectivity regain.
///
/// Failures are classified ([_Attempt]) so one poisoned entry — a node
/// the server will reject forever — can't block everything behind it.
///
/// Call sites can safely latch their own local "already fired" flag the
/// moment they call in; the service owns delivery from that point.
///
/// Folders never call this — they aren't completable.
class ContentCompletionService {
  final RecordContentCompletionUseCase _useCase;

  /// Keys confirmed by the server this session — checked before each
  /// POST so we only ever fire once per node per app run.
  final Set<String> _marked = <String>{};

  /// Keys with an in-flight request, used to dedup concurrent calls
  /// (e.g. video position listener firing twice on the 75% boundary).
  final Set<String> _inFlight = <String>{};

  /// Durable queue, insertion-ordered so retries replay in the order the
  /// student earned them.
  final LinkedHashMap<String, _Pending> _pending =
      LinkedHashMap<String, _Pending>();

  /// The app-wide instance — see core/storage/secure_storage.dart for why
  /// this must not be a locally configured `FlutterSecureStorage`. This
  /// class asking for encrypted prefs while [SessionService] used the
  /// defaults is what migrated the access token out of the store the
  /// session read from, logging the user out on the next launch.
  static const FlutterSecureStorage _storage = secureStorage;

  static const String _kPendingKey = 'crinza_pending_completions';

  /// Give up on an entry after this many failed attempts. Flushes happen
  /// on every launch and every reconnect, so reaching this means the
  /// entry is genuinely undeliverable rather than merely unlucky.
  static const int _maxAttempts = 25;

  /// Hard cap so a pathological offline run can't grow the stored blob
  /// without bound. Oldest entries are evicted first.
  static const int _maxQueueLength = 200;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Guards against two flushes racing (launch + connectivity event).
  bool _flushing = false;

  ContentCompletionService(this._useCase);

  /// Build the cache key the same way every call site does.
  static String _keyFor(int coursePurchasedId, String jsonContentId) =>
      '$coursePurchasedId|$jsonContentId';

  /// Loads any completions stranded by a previous run and retries them,
  /// then starts watching connectivity so a later reconnect drains the
  /// queue without the student having to reopen the content.
  ///
  /// Safe to call more than once. Never throws — a storage read failure
  /// degrades to "no queue restored", not a broken launch.
  Future<void> init() async {
    try {
      final raw = await _storage.read(key: _kPendingKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            final entry = _Pending.fromJson(e);
            if (entry == null) continue;
            _pending[_keyFor(entry.coursePurchasedId, entry.jsonContentId)] =
                entry;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CompletionService: queue restore failed — $e');
    }

    try {
      _connectivitySub ??= Connectivity().onConnectivityChanged.listen((
        results,
      ) {
        final online =
            results.isNotEmpty &&
            results.any((r) => r != ConnectivityResult.none);
        if (online) unawaited(flushPending());
      });
    } catch (e) {
      // Losing the reconnect trigger costs opportunistic retries, not the
      // queue itself — the next launch still flushes. Must not skip the
      // flush below.
      if (kDebugMode) {
        debugPrint('CompletionService: connectivity watch failed — $e');
      }
    }

    await flushPending();
  }

  /// Returns `true` once [markCompleted] has been accepted for the pair —
  /// either confirmed by the server or durably queued. Viewers read this
  /// on mount to skip instantiating their progress plumbing entirely.
  bool isMarked(int coursePurchasedId, String jsonContentId) {
    final key = _keyFor(coursePurchasedId, jsonContentId);
    return _marked.contains(key) || _pending.containsKey(key);
  }

  /// Records completion for the given node. Idempotent — repeated calls
  /// after a successful one (or while one is queued/in flight) are
  /// no-ops.
  ///
  /// Skips silently when `coursePurchasedId == 0` or `jsonContentId` is
  /// empty: that's a preview / non-purchased flow. Both are loud in debug
  /// builds, because a purchased course arriving here with a zero id
  /// means the curriculum payload dropped `coursePurchasedId` and *every*
  /// completion in that course is being silently discarded.
  ///
  /// Never throws: on failure the key stays queued for a later flush.
  Future<void> markCompleted({
    required int coursePurchasedId,
    required String jsonContentId,
  }) async {
    if (coursePurchasedId == 0 || jsonContentId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'CompletionService: SKIPPED — coursePurchasedId=$coursePurchasedId '
          'jsonContentId="$jsonContentId". Completion is not being recorded. '
          'Expected only in preview/unpurchased flows.',
        );
      }
      return;
    }

    final key = _keyFor(coursePurchasedId, jsonContentId);
    if (_marked.contains(key) ||
        _inFlight.contains(key) ||
        _pending.containsKey(key)) {
      return;
    }

    // Write-ahead: persist BEFORE the request. If the process dies while
    // the POST is in flight, the next launch still finds and delivers it.
    final entry = _Pending(coursePurchasedId, jsonContentId);
    _pending[key] = entry;
    _evictOverflow();
    await _persist();

    final outcome = await _post(key, entry);
    await _applyOutcome(key, entry, outcome);
  }

  /// Retries every queued completion. Entries that are delivered or
  /// permanently rejected leave the queue; transient failures stay.
  /// Stops early only when the device is offline, since nothing else
  /// could succeed either.
  Future<void> flushPending() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    try {
      var changed = false;
      // Snapshot — `_pending` is mutated as entries drain.
      for (final key in _pending.keys.toList(growable: false)) {
        final entry = _pending[key];
        if (entry == null) continue;
        if (_marked.contains(key)) {
          _pending.remove(key);
          changed = true;
          continue;
        }
        final outcome = await _post(key, entry);
        changed = true;
        if (outcome == _Attempt.offline) {
          // Still no connection — leave the rest of the queue intact and
          // wait for the connectivity listener to wake us.
          entry.attempts++;
          break;
        }
        await _applyOutcome(key, entry, outcome, persist: false);
      }
      if (changed) await _persist();
    } finally {
      _flushing = false;
    }
  }

  /// Applies a POST outcome to the queue. [persist] is false when the
  /// caller batches a single write at the end of a flush.
  Future<void> _applyOutcome(
    String key,
    _Pending entry,
    _Attempt outcome, {
    bool persist = true,
  }) async {
    switch (outcome) {
      case _Attempt.delivered:
        _marked.add(key);
        _pending.remove(key);
      case _Attempt.permanent:
        // The server will never accept this one. Dropping it is the only
        // way to stop it blocking the queue — log loudly so a systematic
        // rejection is visible rather than silently eaten.
        _pending.remove(key);
        if (kDebugMode) {
          debugPrint('CompletionService: DROPPED (rejected by server) $key');
        }
      case _Attempt.offline:
      case _Attempt.retryable:
        entry.attempts++;
        if (entry.attempts >= _maxAttempts) {
          _pending.remove(key);
          if (kDebugMode) {
            debugPrint(
              'CompletionService: DROPPED after $_maxAttempts attempts $key',
            );
          }
        }
    }
    if (persist) await _persist();
  }

  /// Attempts the POST for [entry] and classifies the result.
  Future<_Attempt> _post(String key, _Pending entry) async {
    if (_inFlight.contains(key)) return _Attempt.retryable;
    _inFlight.add(key);
    try {
      final result = await _useCase(
        coursePurchasedId: entry.coursePurchasedId,
        jsonContentId: entry.jsonContentId,
      );
      return result.fold(
        (failure) {
          final outcome = _classify(failure);
          if (kDebugMode) {
            debugPrint(
              'CompletionService: POST failed for $key '
              '(${outcome.name}, attempt ${entry.attempts + 1}) — '
              '${failure.message}',
            );
          }
          return outcome;
        },
        (_) {
          if (kDebugMode) debugPrint('CompletionService: marked $key');
          return _Attempt.delivered;
        },
      );
    } catch (e) {
      // Defensive: the repository already maps DioExceptions to Lefts,
      // but an unexpected throw must not lose the completion.
      if (kDebugMode) debugPrint('CompletionService: POST threw for $key — $e');
      return _Attempt.retryable;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Maps a [Failure] onto queue behaviour.
  ///
  /// 401/403 are deliberately *retryable*, not permanent: the usual cause
  /// is an expired token, and the same student logging back in should
  /// still get credit for what they consumed.
  static _Attempt _classify(Failure failure) {
    return failure.when(
      network: (_) => _Attempt.offline,
      cache: (_) => _Attempt.retryable,
      unknown: (_) => _Attempt.retryable,
      server: (_, statusCode) {
        if (statusCode == null) return _Attempt.retryable;
        if (statusCode == 401 || statusCode == 403) return _Attempt.retryable;
        if (statusCode == 408 || statusCode == 429) return _Attempt.retryable;
        if (statusCode >= 500) return _Attempt.retryable;
        if (statusCode >= 400) return _Attempt.permanent;
        return _Attempt.retryable;
      },
    );
  }

  void _evictOverflow() {
    while (_pending.length > _maxQueueLength) {
      final oldest = _pending.keys.first;
      _pending.remove(oldest);
      if (kDebugMode) {
        debugPrint('CompletionService: DROPPED (queue full) $oldest');
      }
    }
  }

  Future<void> _persist() async {
    try {
      if (_pending.isEmpty) {
        await _storage.delete(key: _kPendingKey);
      } else {
        await _storage.write(
          key: _kPendingKey,
          value: jsonEncode(
            _pending.values.map((e) => e.toJson()).toList(growable: false),
          ),
        );
      }
    } catch (e) {
      // Storage failure leaves the queue in memory only — it still
      // retries this session, just not across a restart.
      if (kDebugMode) debugPrint('CompletionService: queue persist failed — $e');
    }
  }

  /// Forgets every cached and queued completion for one purchase.
  ///
  /// Called after a successful course **rewatch**, which zeroes progress
  /// server-side. Without this the session cache would still report the
  /// course's nodes as marked, so re-watching a lecture or reopening a
  /// document would post nothing and progress would sit at 0 until the
  /// app was restarted.
  ///
  /// Queued-but-undelivered entries for the course are dropped too:
  /// they were earned before the reset the student just asked for, so
  /// delivering them afterwards would re-credit that same content.
  Future<void> forgetCourse(int coursePurchasedId) async {
    if (coursePurchasedId == 0) return;
    final prefix = '$coursePurchasedId|';
    _marked.removeWhere((k) => k.startsWith(prefix));
    final dropped = _pending.keys
        .where((k) => k.startsWith(prefix))
        .toList(growable: false);
    for (final k in dropped) {
      _pending.remove(k);
    }
    if (dropped.isNotEmpty) await _persist();
  }

  /// Best-effort drain then wipe, for **explicit** logout only.
  ///
  /// The queue is device-scoped, so leaving entries behind would let the
  /// next account on this handset deliver them under its own token —
  /// crediting the wrong student. Draining first means a connected
  /// student loses nothing; an offline one forfeits queued completions,
  /// which is the safer of the two failure modes.
  ///
  /// Deliberately NOT called from the 401 auto-logout path: that's an
  /// expired token for the *same* student, who should keep their queue.
  Future<void> clearForLogout() async {
    await flushPending();
    _marked.clear();
    _inFlight.clear();
    _pending.clear();
    await _persist();
  }

  /// Number of completions still awaiting delivery. Exposed for debug
  /// surfaces and tests.
  int get pendingCount => _pending.length;

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Test/utility — wipes the local caches and the persisted queue.
  @visibleForTesting
  Future<void> resetCache() async {
    _marked.clear();
    _inFlight.clear();
    _pending.clear();
    await _persist();
  }
}
