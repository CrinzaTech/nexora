import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_cart_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// K1 — the cart, with live prices and stock.
class GetStoreCartUseCase {
  final StoreRepository repository;

  GetStoreCartUseCase(this.repository);

  Future<Either<Failure, StoreCart>> call() => repository.getCart();
}

/// K2 — **sets** the quantity (0 removes), so a retry is harmless.
/// Answers with the whole cart.
class SetStoreCartQtyUseCase {
  final StoreRepository repository;

  SetStoreCartQtyUseCase(this.repository);

  Future<Either<Failure, StoreCart>> call(String productId, int qty) =>
      repository.setCartQty(productId, qty);
}

/// K3.
class RemoveFromStoreCartUseCase {
  final StoreRepository repository;

  RemoveFromStoreCartUseCase(this.repository);

  Future<Either<Failure, StoreCart>> call(String productId) =>
      repository.removeFromCart(productId);
}

/// K4.
class ClearStoreCartUseCase {
  final StoreRepository repository;

  ClearStoreCartUseCase(this.repository);

  Future<Either<Failure, StoreCart>> call() => repository.clearCart();
}

/// K5 — the badge.
class GetStoreCartCountUseCase {
  final StoreRepository repository;

  GetStoreCartCountUseCase(this.repository);

  Future<Either<Failure, int>> call() => repository.getCartCount();
}
