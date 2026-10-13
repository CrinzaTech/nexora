import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_checkout_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// P1, P2 and P3 (STORE_API.md §7). **The order is placed by the server,
/// not by the Razorpay callback**: P3 — or, if the app dies first, the
/// Razorpay webhook — is what turns a payment into an order.

/// P1 — the price breakdown. Called whenever the address or cart changes.
class GetStoreQuoteUseCase {
  final StoreRepository repository;

  GetStoreQuoteUseCase(this.repository);

  Future<Either<Failure, StoreQuote>> call(
    StoreCheckoutSource source,
    int addressId,
  ) => repository.quote(source, addressId);
}

/// P2 — re-prices on the server and holds stock for 30 minutes. The same
/// [idempotencyKey] always returns the same order.
class PlaceStoreOrderUseCase {
  final StoreRepository repository;

  PlaceStoreOrderUseCase(this.repository);

  Future<Either<Failure, StorePlacedOrder>> call(
    StoreCheckoutSource source,
    int addressId,
    String idempotencyKey,
  ) => repository.placeOrder(source, addressId, idempotencyKey);
}

/// P3 — confirm the payment Razorpay reported.
class VerifyStorePaymentUseCase {
  final StoreRepository repository;

  VerifyStorePaymentUseCase(this.repository);

  Future<Either<Failure, StoreVerifyResult>> call(
    String orderNo, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) => repository.verifyPayment(
    orderNo,
    razorpayOrderId: razorpayOrderId,
    razorpayPaymentId: razorpayPaymentId,
    razorpaySignature: razorpaySignature,
  );
}
