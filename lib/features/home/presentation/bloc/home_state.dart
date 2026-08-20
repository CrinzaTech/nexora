part of 'home_cubit.dart';

/// Home state with Freezed pattern
@freezed
class HomeState with _$HomeState {
  /// Initial state
  const factory HomeState.initial() = _Initial;

  /// Loading state
  const factory HomeState.loading() = _Loading;

  /// Loaded state with dashboard data
  const factory HomeState.loaded(DashboardData dashboard) = _Loaded;

  /// Error state
  const factory HomeState.error(String message) = _Error;
}
