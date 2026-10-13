import 'package:dartz/dartz.dart' show Either;
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/services/store_location_service.dart';
import 'package:nexora/features/store/domain/usecases/store_address_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_address_form_state.dart';
part 'store_address_form_cubit.freezed.dart';

/// A1 (the state list) + A3 / A4 (save) for the add / edit form, plus
/// "Use my current location".
class StoreAddressFormCubit extends SafeCubit<StoreAddressFormState> {
  final GetStoreStatesUseCase getStatesUseCase;
  final SaveStoreAddressUseCase saveAddressUseCase;
  final StoreLocationService locationService;

  StoreAddressFormCubit({
    required this.getStatesUseCase,
    required this.saveAddressUseCase,
    required this.locationService,
  }) : super(const StoreAddressFormState());

  /// One-tap fill. The page writes the result into its fields, since the
  /// text controllers belong to it.
  Future<Either<StoreLocateError, StoreLocatedAddress>> locate() async {
    emit(state.copyWith(locating: true));
    final result = await locationService.locate();
    emit(state.copyWith(locating: false));
    return result;
  }

  /// The A1 entry for a state as the platform names it — "NCT of Delhi"
  /// and "Delhi" are the same place. Null when nothing fits.
  StoreGstState? matchState(String? name) {
    if (name == null || state.states.isEmpty) return null;
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z]'), '');
    final target = norm(name);
    if (target.isEmpty) return null;
    for (final s in state.states) {
      if (norm(s.name) == target) return s;
    }
    for (final s in state.states) {
      final n = norm(s.name);
      if (n.contains(target) || target.contains(n)) return s;
    }
    return null;
  }

  Future<void> loadStates() async {
    emit(state.copyWith(loadingStates: true, statesError: null));
    final result = await getStatesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingStates: false,
          statesError: storeErrorText(failure),
        ),
      ),
      (states) => emit(
        state.copyWith(
          loadingStates: false,
          states: [...states]..sort((a, b) => a.name.compareTo(b.name)),
        ),
      ),
    );
  }

  /// Returns the saved address, or null after emitting [saveError].
  Future<StoreAddress?> save(StoreAddressInput input, {int? id}) async {
    emit(state.copyWith(saving: true, saveError: null));
    final result = await saveAddressUseCase(input, id: id);
    return result.fold(
      (failure) {
        emit(state.copyWith(saving: false, saveError: storeErrorText(failure)));
        return null;
      },
      (address) {
        emit(state.copyWith(saving: false));
        return address;
      },
    );
  }
}
