import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/domain/usecases/news_usecases.dart';

part 'news_home_state.dart';
part 'news_home_cubit.freezed.dart';

/// The News badge and the Home popup, shared app-wide.
///
/// A DI singleton provided above `MaterialApp`, so the Discover row's
/// badge, the panel and the push detail page all read and lower one
/// count. Every "read" PUT goes through [markRead] / [markAllRead] for the
/// same reason.
///
/// News is never allowed to get in Home's way: every call here is silent,
/// and a failure leaves the badge as it was — no error UI, no retry loop.
class NewsHomeCubit extends SafeCubit<NewsHomeState> {
  final GetNewsHomeUseCase getNewsHomeUseCase;
  final MarkNewsPopupShownUseCase markPopupShownUseCase;
  final MarkNewsReadUseCase markReadUseCase;
  final MarkAllNewsReadUseCase markAllReadUseCase;

  NewsHomeCubit({
    required this.getNewsHomeUseCase,
    required this.markPopupShownUseCase,
    required this.markReadUseCase,
    required this.markAllReadUseCase,
  }) : super(const NewsHomeState());

  /// The popup shows once per app session, even if `/news/home` answers
  /// again before the dialog's `popup-shown` has reached the server.
  bool _popupShownThisSession = false;

  /// Posts read on this device this session. A push can open (and read) a
  /// post while a `/news/home` that predates the read is still in flight;
  /// this keeps that post from popping up on top of itself.
  final Set<int> _readThisSession = {};

  /// `GET /news/home`. Safe to call as often as Home likes.
  Future<void> refresh() async {
    final result = await getNewsHomeUseCase();
    result.fold(
      (failure) =>
          Utils.debugLog('NewsHomeCubit: refresh failed: ${failure.message}'),
      (summary) {
        final popups = _popupShownThisSession
            ? const <NewsItem>[]
            : summary.popups
                  .where((p) => !_readThisSession.contains(p.newsId))
                  .toList();
        emit(NewsHomeState(unreadCount: summary.unreadCount, popups: popups));
      },
    );
  }

  /// Hands the waiting popups to the dialog and latches the session flag.
  /// Empty when there is nothing to show or the popup already ran.
  List<NewsItem> takePopups() {
    if (_popupShownThisSession || state.popups.isEmpty) return const [];
    _popupShownThisSession = true;
    final popups = state.popups;
    emit(state.copyWith(popups: const []));
    return popups;
  }

  /// The dialog closed, however it closed. Fire and forget: calling twice
  /// is harmless and unknown ids are ignored by the server.
  void popupClosed(List<int> newsIds) {
    if (newsIds.isEmpty) return;
    unawaited(
      markPopupShownUseCase(newsIds).then(
        (r) => r.fold(
          (f) =>
              Utils.debugLog('NewsHomeCubit: popup-shown failed: ${f.message}'),
          (_) {},
        ),
      ),
    );
  }

  /// Lowers the badge straight away and tells the server in the
  /// background. Already-read posts send nothing. A post that has since
  /// gone answers `success: false`, which is ignored.
  void markRead(NewsItem item) {
    _readThisSession.add(item.newsId);
    if (item.isRead) return;
    if (state.unreadCount > 0) {
      emit(state.copyWith(unreadCount: state.unreadCount - 1));
    }
    unawaited(
      markReadUseCase(item.newsId).then(
        (r) => r.fold(
          (f) => Utils.debugLog(
            'NewsHomeCubit: read(${item.newsId}) failed: ${f.message}',
          ),
          (_) {},
        ),
      ),
    );
  }

  /// Clears the badge straight away; the server catches up in the
  /// background. A failure is fixed by the next [refresh].
  void markAllRead() {
    emit(state.copyWith(unreadCount: 0));
    unawaited(
      markAllReadUseCase().then(
        (r) => r.fold(
          (f) => Utils.debugLog('NewsHomeCubit: read-all failed: ${f.message}'),
          (_) {},
        ),
      ),
    );
  }

  /// The panel's first page carries the server's current count — fresher
  /// than whatever Home last saw.
  void syncUnreadCount(int count) =>
      emit(state.copyWith(unreadCount: count < 0 ? 0 : count));

  /// On logout, so the next account starts with a clean badge and gets its
  /// own popup.
  void reset() {
    _popupShownThisSession = false;
    _readThisSession.clear();
    emit(const NewsHomeState());
  }
}
