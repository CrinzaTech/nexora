import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/models/store_cart_model.dart';
import 'package:nexora/features/store/data/models/store_checkout_model.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';

/// The learner's side of the Store (STORE_API.md).
///
/// Actions that answer with nothing but a sentence (cancel, received,
/// review) return the server's `message`, which is written to be shown.
abstract class StoreRepository {
  // Catalog
  Future<Either<Failure, StoreHome>> getHome();
  Future<Either<Failure, StorePage<StoreProductCard>>> getProducts(
    StoreProductQuery query, {
    int pageNo = 1,
    int pageSize = 20,
  });
  Future<Either<Failure, StoreProductDetail>> getProduct(String productId);
  Future<Either<Failure, StorePage<StoreReview>>> getReviews(
    String productId, {
    int pageNo = 1,
    int pageSize = 20,
  });

  // Addresses
  Future<Either<Failure, List<StoreGstState>>> getStates();
  Future<Either<Failure, List<StoreAddress>>> getAddresses();
  Future<Either<Failure, StoreAddress>> saveAddress(
    StoreAddressInput input, {
    int? id,
  });
  Future<Either<Failure, Unit>> deleteAddress(int id);
  Future<Either<Failure, Unit>> makeDefaultAddress(int id);

  // Cart
  Future<Either<Failure, StoreCart>> getCart();
  Future<Either<Failure, StoreCart>> setCartQty(String productId, int qty);
  Future<Either<Failure, StoreCart>> removeFromCart(String productId);
  Future<Either<Failure, StoreCart>> clearCart();
  Future<Either<Failure, int>> getCartCount();

  // Checkout
  Future<Either<Failure, StoreQuote>> quote(
    StoreCheckoutSource source,
    int addressId,
  );
  Future<Either<Failure, StorePlacedOrder>> placeOrder(
    StoreCheckoutSource source,
    int addressId,
    String idempotencyKey,
  );
  Future<Either<Failure, StoreVerifyResult>> verifyPayment(
    String orderNo, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

  // My orders
  Future<Either<Failure, StorePage<StoreOrderSummary>>> getOrders(
    StoreOrderGroup group, {
    int pageNo = 1,
    int pageSize = 10,
  });
  Future<Either<Failure, StoreOrderDetail>> getOrder(String orderNo);
  Future<Either<Failure, String>> cancelOrder(String orderNo, {String? reason});
  Future<Either<Failure, String>> confirmReceived(String orderNo);
  Future<Either<Failure, String>> reviewItem(
    String orderNo,
    int itemId, {
    required int rating,
    String? comment,
  });
}
