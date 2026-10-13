part of 'store_addresses_cubit.dart';

@freezed
abstract class StoreAddressesState with _$StoreAddressesState {
  const factory StoreAddressesState({
    /// The default first.
    @Default(<StoreAddress>[]) List<StoreAddress> items,
    @Default(false) bool loading,
    @Default(false) bool loaded,

    /// The address with a delete / make-default in flight.
    int? busyId,
    String? error,
  }) = _StoreAddressesState;
}
