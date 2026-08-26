import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_detail_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_my_courses_usecase.dart';

part 'live_now_state.dart';
part 'live_now_cubit.freezed.dart';

/// One live class the learner owns, with the course context needed to
/// join it.
class LiveClassLead {
  final int courseId;
  final int coursePurchasedId;
  final String courseTitle;
  final String courseImageUrl;
  final bool activateWatermark;

  /// The live-class node itself — owns the room id (`url`), the schedule
  /// and the [CourseContent.isLiveNow] window.
  final CourseContent node;

  const LiveClassLead({
    required this.courseId,
    required this.coursePurchasedId,
    required this.courseTitle,
    required this.courseImageUrl,
    required this.activateWatermark,
    required this.node,
  });

  bool get isLiveNow => node.isLiveNow;

  /// The same deep link the curriculum's module card builds, so joining
  /// from Home lands in exactly the same place, with the same completion
  /// tracking and the same watermark.
  String get joinRoute =>
      '${AppRoutes.liveClass}'
      '?title=${Uri.encodeComponent(node.nodeName)}'
      '&url=${Uri.encodeComponent(node.url ?? '')}'
      '&courseId=$courseId'
      '&coursePurchasedId=$coursePurchasedId'
      '&nodeId=${Uri.encodeComponent(node.nodeId)}'
      '${node.startDateTime != null ? '&scheduledAt=${Uri.encodeComponent(node.startDateTime!.toIso8601String())}' : ''}'
      '&activateWatermark=$activateWatermark';
}

/// Works out which of the learner's own courses has a class on air, for
/// the "Live now" rail on Home.
///
/// ## Why it is shaped like this
///
/// No endpoint reports this. `/dashboard` carries no purchased-course
/// data at all, and `/my-courses` returns [CourseSummary] — title,
/// image, progress, `purchasedId` — with nothing about live sessions.
/// Live-class nodes exist in exactly one place: `courseNodes.content`
/// inside `GET /api/v1/course/{courseId}/v2`.
///
/// So the schedule has to be assembled: one `/my-courses` call, then one
/// course-detail call per owned course, walking each tree for
/// [CourseContentType.liveClass] nodes.
///
/// That is expensive, so it is done **once** and then read locally. A
/// class's start time and duration do not change minute to minute, so
/// the fetched schedule is cached for [_scheduleTtl] and a [_tick]
/// timer re-evaluates [CourseContent.isLiveNow] against it with no
/// network at all. The cost is 1+N requests per app session, not per
/// visit to Home.
///
/// ## What it cannot know
///
/// [CourseContent.isLiveNow] is a *scheduled window* measured on the
/// **device** clock — `startDateTime <= now < startDateTime + duration`.
/// It means "this class is scheduled to be on air", not "the host has
/// started streaming"; only the room itself knows that, and only after
/// joining. A class the host never starts still lights the rail up, one
/// that runs past its scheduled duration drops off it, and a device with
/// a wrong clock gets both wrong. The curriculum's own LIVE badge has
/// worked this way since it was written, so the rail is at least
/// consistent with it.
class LiveNowCubit extends SafeCubit<LiveNowState> {
  final GetMyCoursesUseCase getMyCoursesUseCase;
  final GetCourseDetailUseCase getCourseDetailUseCase;

  LiveNowCubit({
    required this.getMyCoursesUseCase,
    required this.getCourseDetailUseCase,
  }) : super(const LiveNowState.initial());

  /// How long an assembled schedule is trusted. Long, because gathering
  /// it costs a request per owned course; a class added or rescheduled
  /// inside the window is picked up on the next expiry or [refresh].
  static const _scheduleTtl = Duration(minutes: 30);

  /// How often the cached schedule is re-checked against the clock.
  /// Matches the 30s cadence the curriculum's module rows already use to
  /// flip themselves from "upcoming" to "live".
  static const _tick = Duration(seconds: 30);

  /// Course-detail requests in flight at once. Small on purpose: these
  /// are the heaviest payloads in the app, and this runs behind a screen
  /// the learner is already using.
  static const _batchSize = 3;

  List<LiveClassLead> _schedule = const [];
  DateTime? _fetchedAt;
  Timer? _ticker;
  bool _loading = false;

  /// Set of node ids last emitted, so a 30s tick that changes nothing
  /// does not rebuild Home.
  String _lastKey = '';

  bool get _stale {
    final at = _fetchedAt;
    return at == null || DateTime.now().difference(at) >= _scheduleTtl;
  }

  /// Assembles the schedule if it is missing or stale, then publishes
  /// whatever is live right now. Cheap and safe to call repeatedly — a
  /// fresh cache short-circuits to a local re-evaluation.
  Future<void> load({bool force = false}) async {
    _startTicker();
    if (_loading) return;
    if (!force && !_stale) {
      _publish();
      return;
    }
    _loading = true;
    try {
      final coursesResult = await getMyCoursesUseCase();
      if (isClosed) return;
      final courses = coursesResult.fold(
        (_) => const <CourseSummary>[],
        (list) => list,
      );

      final leads = <LiveClassLead>[];
      for (var i = 0; i < courses.length; i += _batchSize) {
        if (isClosed) return;
        final batch = courses.skip(i).take(_batchSize);
        final results = await Future.wait(batch.map(_leadsForCourse));
        for (final result in results) {
          leads.addAll(result);
        }
      }
      if (isClosed) return;
      _schedule = leads;
      _fetchedAt = DateTime.now();
    } finally {
      _loading = false;
    }
    _publish();
  }

  /// Re-gather from the network — for pull-to-refresh, and for the case
  /// where a learner has just been told a class started.
  Future<void> refresh() => load(force: true);

  /// Every live-class node in one course, flattened out of the tree.
  Future<List<LiveClassLead>> _leadsForCourse(CourseSummary course) async {
    final result = await getCourseDetailUseCase(courseId: course.courseId);
    return result.fold((_) => const <LiveClassLead>[], (detail) {
      final nodes = detail.courseNodes;
      if (nodes == null) return const <LiveClassLead>[];
      final out = <LiveClassLead>[];
      void walk(List<CourseContent> content) {
        for (final node in content) {
          // A live node with no room id cannot be joined — the module
          // card refuses it too, rather than opening a dead player.
          if (node.isLiveClass && (node.url ?? '').isNotEmpty) {
            out.add(
              LiveClassLead(
                courseId: detail.courseId,
                coursePurchasedId: detail.coursePurchasedId,
                courseTitle: detail.courseTitle,
                courseImageUrl: detail.courseImageUrl,
                activateWatermark: nodes.activateWatermark,
                node: node,
              ),
            );
          }
          if (node.children.isNotEmpty) walk(node.children);
        }
      }

      walk(nodes.content);
      return out;
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      // A long session outlives the cache; top it up in the background
      // rather than making the learner pull to refresh.
      if (_stale) {
        load();
      } else {
        _publish();
      }
    });
  }

  void _publish() {
    final live = _schedule
        .where((lead) => lead.isLiveNow)
        .toList(growable: false);
    final key = live.map((lead) => lead.node.nodeId).join('|');
    if (key == _lastKey && state is! _Initial) return;
    _lastKey = key;
    emit(LiveNowState.loaded(live));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
