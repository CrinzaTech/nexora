import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexora/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:nexora/features/home/data/models/home_model.dart';

part 'home_state.dart';
part 'home_cubit.freezed.dart';

/// Home Cubit for managing home screen state
class HomeCubit extends SafeCubit<HomeState> {
  final GetHomeDataUseCase getHomeDataUseCase;

  HomeCubit(this.getHomeDataUseCase) : super(const HomeState.initial());

  /// Load home data
  Future<void> loadHomeData() async {
    emit(const HomeState.loading());

    final result = await getHomeDataUseCase();

    result.fold(
      (failure) => emit(HomeState.error(failure.message)),
      (dashboard) => emit(HomeState.loaded(dashboard)),
    );
  }

  /// Refresh home data
  Future<void> refresh() async {
    await loadHomeData();
  }

  /// Refetch the dashboard without flashing the loading skeleton.
  ///
  /// Used when the dashboard re-enters the Home tab — the user already sees
  /// stale (but valid) content, so we keep it on screen and quietly swap in
  /// fresh data when the request resolves. Errors during the silent refresh
  /// are swallowed so we never demote a loaded screen back to an error view.
  Future<void> silentRefresh() async {
    final result = await getHomeDataUseCase();
    result.fold(
      (_) {}, // keep showing the previous loaded data
      (dashboard) => emit(HomeState.loaded(dashboard)),
    );
  }

  /// Reset state to initial
  void reset() {
    emit(const HomeState.initial());
  }
}
