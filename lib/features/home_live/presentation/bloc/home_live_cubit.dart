import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/domain/usecases/get_home_live_sessions_usecase.dart';

part 'home_live_state.dart';
part 'home_live_cubit.freezed.dart';

/// Drives the "Live classes" rail on Home.
///
/// Owned by the Dashboard alongside [WebinarsCubit] so re-entering the
/// Home tab can refresh it — a class that went live while the learner
/// was elsewhere must show its badge without a restart.
class HomeLiveCubit extends SafeCubit<HomeLiveState> {
  final GetHomeLiveSessionsUseCase getHomeLiveSessionsUseCase;

  /// The rail shows the first page only (the server clamps to 50).
  static const int pageSize = 10;

  HomeLiveCubit({required this.getHomeLiveSessionsUseCase})
    : super(const HomeLiveState.initial());

  bool _isLoadingMore = false;

  /// Keeps the rail current on its own. Re-entering Home and pull-to-
  /// refresh already refetch, but a learner sitting on Home when a class
  /// goes live — or its start time passes and the badge should flip to
  /// "Starting soon" — would otherwise see nothing change. The cadence
  /// follows how soon anything can change: tight while something is on
  /// air or imminent, relaxed otherwise. One small GET either way.
  Timer? _poll;
  static const _pollHot = Duration(seconds: 20);
  static const _pollWarm = Duration(minutes: 1);
  static const _pollCold = Duration(minutes: 5);

  Future<void> load() => _fetch(showLoading: true);

  /// Refetch without flashing `loading`, so the rail never blanks out
  /// under the learner while they are looking at it.
  Future<void> silentRefresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const HomeLiveState.loading());
    final result = await getHomeLiveSessionsUseCase(
      pageNo: 1,
      pageSize: pageSize,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        // A silent refresh that fails leaves the current list alone; a
        // failed first load renders nothing (the rail is supplementary).
        if (showLoading) emit(HomeLiveState.error(failure.message));
        _schedulePoll(const []);
      },
      (page) {
        emit(
          HomeLiveState.loaded(
            sessions: page.sessions,
            liveCount: page.liveCount,
            total: page.total,
            hasMore: page.hasMore,
            pageNo: page.pageNo,
          ),
        );
        _schedulePoll(page.sessions);
      },
    );
  }

  /// A card's countdown just hit zero — ask the server right away whether
  /// the educator is on air, instead of waiting for the next poll.
  void onCountdownElapsed() => silentRefresh();

  void _schedulePoll(List<HomeLiveSessionItem> sessions) {
    _poll?.cancel();
    _poll = Timer(_pollIntervalFor(sessions), () {
      if (!isClosed) silentRefresh();
    });
  }

  Duration _pollIntervalFor(List<HomeLiveSessionItem> sessions) {
    if (sessions.isEmpty) return _pollCold;
    var soonest = const Duration(days: 365);
    for (final s in sessions) {
      if (s.isOnAir || s.isPaused || s.isWaitingForHost) return _pollHot;
      final left = s.timeUntilStart;
      if (left < soonest) soonest = left;
    }
    if (soonest <= const Duration(minutes: 10)) return _pollHot;
    if (soonest <= const Duration(hours: 1)) return _pollWarm;
    return _pollCold;
  }

  /// Appends the next page. No-op unless `loaded` with more to fetch;
  /// re-entrant calls are dropped rather than queued.
  Future<void> loadMore() async {
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    emit(current.copyWith(isLoadingMore: true));

    final result = await getHomeLiveSessionsUseCase(
      pageNo: current.pageNo + 1,
      pageSize: pageSize,
    );
    _isLoadingMore = false;

    result.fold(
      (_) => emit(current.copyWith(isLoadingMore: false)),
      (page) => emit(
        current.copyWith(
          sessions: [...current.sessions, ...page.sessions],
          liveCount: page.liveCount,
          total: page.total,
          hasMore: page.hasMore,
          pageNo: page.pageNo,
          isLoadingMore: false,
        ),
      ),
    );
  }

  void reset() => emit(const HomeLiveState.initial());

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
