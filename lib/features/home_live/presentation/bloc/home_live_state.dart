part of 'home_live_cubit.dart';

@freezed
sealed class HomeLiveState with _$HomeLiveState {
  const factory HomeLiveState.initial() = _Initial;
  const factory HomeLiveState.loading() = _Loading;
  const factory HomeLiveState.loaded({
    @Default(<HomeLiveSessionItem>[]) List<HomeLiveSessionItem> sessions,
    @Default(0) int liveCount,
    @Default(0) int total,
    @Default(false) bool hasMore,
    @Default(1) int pageNo,
    @Default(false) bool isLoadingMore,
  }) = _Loaded;
  const factory HomeLiveState.error(String message) = _Error;
}
