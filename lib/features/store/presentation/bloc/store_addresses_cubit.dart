import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/domain/usecases/store_address_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_addresses_state.dart';
part 'store_addresses_cubit.freezed.dart';

/// A2 / A5 / A6 — the learner's address book.
class StoreAddressesCubit extends SafeCubit<StoreAddressesState> {
  final GetStoreAddressesUseCase getAddressesUseCase;
  final DeleteStoreAddressUseCase deleteAddressUseCase;
  final MakeDefaultStoreAddressUseCase makeDefaultUseCase;

  StoreAddressesCubit({
    required this.getAddressesUseCase,
    required this.deleteAddressUseCase,
    required this.makeDefaultUseCase,
  }) : super(const StoreAddressesState());

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(loading: true, error: null));
    final result = await getAddressesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          loading: false,
          // A silent refresh keeps the list it already has.
          error: silent && state.loaded ? null : storeErrorText(failure),
        ),
      ),
      (items) => emit(
        state.copyWith(
          loading: false,
          loaded: true,
          items: _defaultFirst(items),
          error: null,
        ),
      ),
    );
  }

  /// Returns null on success or a message to show.
  Future<String?> delete(int id) async {
    emit(state.copyWith(busyId: id));
    final result = await deleteAddressUseCase(id);
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(busyId: null));
      return storeErrorText(failure);
    }
    // Deleting the default moves it server-side; re-read rather than
    // guess which address inherited it.
    await load(silent: true);
    emit(state.copyWith(busyId: null));
    return null;
  }

  Future<String?> makeDefault(int id) async {
    emit(state.copyWith(busyId: id));
    final result = await makeDefaultUseCase(id);
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(busyId: null));
      return storeErrorText(failure);
    }
    await load(silent: true);
    emit(state.copyWith(busyId: null));
    return null;
  }

  static List<StoreAddress> _defaultFirst(List<StoreAddress> items) => [
    ...items.where((a) => a.isDefault),
    ...items.where((a) => !a.isDefault),
  ];
}
