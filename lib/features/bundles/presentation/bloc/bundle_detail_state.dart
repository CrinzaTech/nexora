part of 'bundle_detail_cubit.dart';

@freezed
sealed class BundleDetailState with _$BundleDetailState {
  const factory BundleDetailState.loading() = _Loading;
  const factory BundleDetailState.loaded(BundleDetail bundle) = _Loaded;

  /// [notFound] is a 404: the bundle is gone or was never this org's, so
  /// retrying is pointless.
  const factory BundleDetailState.error(String message, bool notFound) = _Error;
}
