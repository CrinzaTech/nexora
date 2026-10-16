part of 'news_list_cubit.dart';

@freezed
sealed class NewsListState with _$NewsListState {
  const factory NewsListState.initial() = _Initial;
  const factory NewsListState.loading() = _Loading;

  /// [items] accumulates across pages; [page] is the most recent response
  /// and carries `hasMore` and the read-back `pageSize`.
  ///
  /// An empty [items] is a normal answer ("No news right now."), not an
  /// error.
  const factory NewsListState.loaded(List<NewsItem> items, NewsPage page) =
      _Loaded;

  const factory NewsListState.error(String message) = _Error;
}
