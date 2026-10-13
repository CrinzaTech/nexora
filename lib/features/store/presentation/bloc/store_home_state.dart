part of 'store_home_cubit.dart';

@freezed
sealed class StoreHomeState with _$StoreHomeState {
  const factory StoreHomeState.initial() = _Initial;
  const factory StoreHomeState.loading() = _Loading;
  const factory StoreHomeState.loaded(StoreHome home) = _Loaded;

  /// 403 "The store is not available." — the org has it switched off.
  const factory StoreHomeState.unavailable() = _Unavailable;
  const factory StoreHomeState.error(String message) = _Error;
}
