part of 'webinars_cubit.dart';

@freezed
class WebinarsState with _$WebinarsState {
  const factory WebinarsState.initial() = _Initial;
  const factory WebinarsState.loading() = _Loading;
  const factory WebinarsState.loaded({
    @Default(<WebinarItem>[]) List<WebinarItem> webinars,
    @Default(0) int liveCount,
    @Default(0) int total,
    @Default(false) bool hasMore,
    @Default(1) int pageNo,
    @Default(false) bool isLoadingMore,
  }) = _Loaded;
  const factory WebinarsState.error(String message) = _Error;
}
