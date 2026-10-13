part of 'store_address_form_cubit.dart';

@freezed
abstract class StoreAddressFormState with _$StoreAddressFormState {
  const factory StoreAddressFormState({
    @Default(<StoreGstState>[]) List<StoreGstState> states,
    @Default(false) bool loadingStates,
    String? statesError,
    @Default(false) bool saving,

    /// "Use my current location" in flight.
    @Default(false) bool locating,
    String? saveError,
  }) = _StoreAddressFormState;
}
