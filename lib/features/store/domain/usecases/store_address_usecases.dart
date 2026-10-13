import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// A1 — states and their GST codes, for the address form's dropdown.
class GetStoreStatesUseCase {
  final StoreRepository repository;

  GetStoreStatesUseCase(this.repository);

  Future<Either<Failure, List<StoreGstState>>> call() => repository.getStates();
}

/// A2 — saved addresses.
class GetStoreAddressesUseCase {
  final StoreRepository repository;

  GetStoreAddressesUseCase(this.repository);

  Future<Either<Failure, List<StoreAddress>>> call() =>
      repository.getAddresses();
}

/// A3 (no [id]) / A4 (with one). The first address saved is always made
/// the default by the server.
class SaveStoreAddressUseCase {
  final StoreRepository repository;

  SaveStoreAddressUseCase(this.repository);

  Future<Either<Failure, StoreAddress>> call(
    StoreAddressInput input, {
    int? id,
  }) => repository.saveAddress(input, id: id);
}

/// A5.
class DeleteStoreAddressUseCase {
  final StoreRepository repository;

  DeleteStoreAddressUseCase(this.repository);

  Future<Either<Failure, Unit>> call(int id) => repository.deleteAddress(id);
}

/// A6.
class MakeDefaultStoreAddressUseCase {
  final StoreRepository repository;

  MakeDefaultStoreAddressUseCase(this.repository);

  Future<Either<Failure, Unit>> call(int id) =>
      repository.makeDefaultAddress(id);
}
