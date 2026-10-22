part of 'bundles_cubit.dart';

@freezed
sealed class BundlesState with _$BundlesState {
  const factory BundlesState.initial() = _Initial;
  const factory BundlesState.loading() = _Loading;
  const factory BundlesState.loaded({
    @Default(<BundleCard>[]) List<BundleCard> bundles,
    @Default(0) int total,
    @Default(false) bool hasMore,
    @Default(1) int pageNo,
    @Default(false) bool isLoadingMore,
  }) = _Loaded;
  const factory BundlesState.error(String message) = _Error;
}
