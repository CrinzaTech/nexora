part of 'news_home_cubit.dart';

@freezed
abstract class NewsHomeState with _$NewsHomeState {
  const factory NewsHomeState({
    /// The News badge. Hidden at 0, `9+` above 9.
    @Default(0) int unreadCount,

    /// Posts waiting for the Home popup dialog. Emptied once they have been
    /// handed to it, and never refilled in the same app session.
    @Default(<NewsItem>[]) List<NewsItem> popups,
  }) = _NewsHomeState;
}
