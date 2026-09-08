import 'dart:async';

import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';

/// Resolves which courses cost nothing, for list screens whose payload
/// doesn't say.
///
/// `GET /api/v1/course/catalog` ships no price and no free-marker per
/// course (`isCourseFree`, `courseType`, `price` are all absent), so
/// [CourseSummary.isCourseFree] parses as `false` and every card falls
/// back to a "Buy Now" CTA — including courses the user can enrol in
/// for free.
///
/// The same endpoint *does* accept `courseType=free` as a filter, so
/// the backend knows the answer even though it doesn't ship it per row.
/// This registry asks that one question once — "which course ids are
/// free?" — caches the id set for [_ttl], and lets the repository stamp
/// `isCourseFree` onto whatever rows it just fetched.
///
/// Failures are swallowed on purpose: an unknown answer degrades to the
/// current "Buy Now" behaviour rather than breaking the list. Once the
/// backend starts sending `isCourseFree` on the catalog rows the model
/// picks it up directly and this becomes a redundant safety net.
class FreeCourseRegistry {
  final ApiClient _apiClient;

  FreeCourseRegistry(this._apiClient);

  /// How long a resolved id set stays usable. Long enough that a user
  /// browsing categories pays for one request, short enough that an
  /// admin flipping a course to free shows up without a restart.
  static const Duration _ttl = Duration(minutes: 10);

  /// Hard stop on paging. A catalog with more free courses than this
  /// is unusual; the cap keeps a runaway `totalPages` from turning one
  /// list load into dozens of requests.
  static const int _maxPages = 10;

  Set<int>? _ids;
  DateTime? _fetchedAt;

  /// Latches once a catalog page comes back with every row carrying its
  /// own free-marker — proof the backend now answers the question
  /// inline. From then on [freeCourseIds] returns nothing and the extra
  /// request stops being made for the rest of the session.
  bool _serverIsAuthoritative = false;

  /// In-flight request, shared by every caller that arrives while the
  /// first one is still running — a catalog screen and its pagination
  /// shouldn't fire the same lookup twice.
  Future<Set<int>>? _inFlight;

  bool get _isFresh {
    final at = _fetchedAt;
    return _ids != null && at != null && DateTime.now().difference(at) < _ttl;
  }

  /// Ids of every free course, from cache when fresh. Returns an empty
  /// set when the lookup fails, or once the backend ships the flag on
  /// the rows themselves.
  Future<Set<int>> freeCourseIds() {
    if (_serverIsAuthoritative) return Future.value(const <int>{});
    if (_isFresh) return Future.value(_ids!);
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  /// Called by the repository when a catalog page arrives fully marked.
  /// Retires this fallback for the session — the rows are now their own
  /// source of truth.
  void markServerAuthoritative() => _serverIsAuthoritative = true;

  Future<Set<int>> _fetch() async {
    final ids = <int>{};
    try {
      for (var page = 1; page <= _maxPages; page++) {
        final json = await _apiClient.getCourseCatalog(
          pageNo: page,
          courseType: 'free',
        );
        final response = CourseCatalogResponse.fromJson(json);
        if (response.courses.isEmpty) break;
        final pageIds = response.courses.map((c) => c.courseId).toSet();
        // The endpoint returns `data` as a bare list, so there's often
        // no page count to stop on. An empty page ends the walk; a page
        // that repeats what we already have means the backend ignored
        // `pageNo`, which would otherwise loop to the cap.
        if (page > 1 && pageIds.every(ids.contains)) break;
        ids.addAll(pageIds);
        final totalPages = response.totalPages;
        if (totalPages != null && page >= totalPages) break;
      }
    } catch (_) {
      // Unknown → treat nothing as free; cards keep their "Buy Now"
      // label instead of the list failing.
      return <int>{};
    }
    _ids = ids;
    _fetchedAt = DateTime.now();
    return ids;
  }
}
