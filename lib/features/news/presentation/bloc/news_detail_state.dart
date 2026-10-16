part of 'news_detail_cubit.dart';

@freezed
sealed class NewsDetailState with _$NewsDetailState {
  const factory NewsDetailState.loading() = _Loading;
  const factory NewsDetailState.loaded(NewsItem item) = _Loaded;

  /// [message] is the server's own wording when it sent one — for a post
  /// that has gone, "This news is no longer available."
  const factory NewsDetailState.error(String message) = _Error;
}
