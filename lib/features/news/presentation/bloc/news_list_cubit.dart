import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/domain/usecases/news_usecases.dart';
import 'package:nexora/features/news/presentation/bloc/news_home_cubit.dart';

part 'news_list_state.dart';
part 'news_list_cubit.freezed.dart';

/// Drives the News & Updates panel: paging plus the read dots.
///
/// The unread count itself lives in [NewsHomeCubit], so a post opened here
/// lowers the Discover badge without a round trip. Paging is driven by
/// `hasMore` alone and repeats the **returned** `pageSize`, since the
/// server clamps it.
class NewsListCubit extends SafeCubit<NewsListState> {
  final GetNewsPageUseCase getNewsPageUseCase;
  final NewsHomeCubit homeCubit;

  NewsListCubit({required this.getNewsPageUseCase, required this.homeCubit})
    : super(const NewsListState.initial());

  static const int _pageSize = 10;

  bool _loadingMore = false;

  Future<void> load() => _fetch(showLoading: true);

  /// Pull-to-refresh: the list stays on screen while it happens.
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const NewsListState.loading());

    final result = await getNewsPageUseCase(pageNo: 1, pageSize: _pageSize);
    if (isClosed) return;

    result.fold(
      (failure) {
        // A failed silent refresh keeps the list that is already useful.
        if (showLoading) emit(NewsListState.error(failure.message));
      },
      (page) {
        homeCubit.syncUnreadCount(page.unreadCount);
        emit(NewsListState.loaded(page.items, page));
      },
    );
  }

  /// Appends the next page silently; a failure is retried by the next
  /// scroll.
  Future<void> loadMore() async {
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null || !current.page.hasMore || _loadingMore) return;

    _loadingMore = true;
    final result = await getNewsPageUseCase(
      pageNo: current.page.pageNo + 1,
      pageSize: current.page.pageSize,
    );
    _loadingMore = false;
    if (isClosed) return;

    result.fold((_) {}, (page) {
      // A post published between pages shifts everything down by one;
      // skip what is already listed rather than show it twice.
      final seen = {for (final n in current.items) n.newsId};
      emit(
        NewsListState.loaded([
          ...current.items,
          ...page.items.where((n) => !seen.contains(n.newsId)),
        ], page),
      );
    });
  }

  /// Flips [item] to read here and lowers the badge, without waiting for
  /// the server. Returns the read copy for the detail page.
  NewsItem open(NewsItem item) {
    homeCubit.markRead(item);
    if (item.isRead) return item;
    final read = item.copyWith(isRead: true);
    final current = state.mapOrNull(loaded: (s) => s);
    if (current != null) {
      emit(
        NewsListState.loaded([
          for (final n in current.items) n.newsId == item.newsId ? read : n,
        ], current.page),
      );
    }
    return read;
  }

  void markAllRead() {
    homeCubit.markAllRead();
    final current = state.mapOrNull(loaded: (s) => s);
    if (current == null) return;
    emit(
      NewsListState.loaded([
        for (final n in current.items) n.isRead ? n : n.copyWith(isRead: true),
      ], current.page),
    );
  }
}
