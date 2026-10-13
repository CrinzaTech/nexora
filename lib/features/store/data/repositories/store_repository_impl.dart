import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/models/store_cart_model.dart';
import 'package:nexora/features/store/data/models/store_checkout_model.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// Talks to the Store API through the shared [Dio] (auth + 401 renewal
/// come from its interceptor) rather than the generated `ApiClient`,
/// whose `.g.dart` is maintained by hand — 24 endpoints of one envelope
/// shape read far better through one helper than as 24 hand-written
/// stubs.
class StoreRepositoryImpl implements StoreRepository {
  final Dio _dio;

  StoreRepositoryImpl(this._dio);

  /// A1 barely ever changes, so one fetch per app run is enough.
  List<StoreGstState>? _states;

  // ── Envelope ───────────────────────────────────────────────────────

  /// Sends [request] and unwraps `{ success, message, data }`.
  ///
  /// A `success: false` on a 2xx is surfaced like any other server
  /// failure so callers only ever branch on one shape.
  Future<Either<Failure, T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data, String message) parse,
  ) async {
    try {
      final res = await request();
      final body = res.data;
      final envelope = body is Map ? body : const {};
      final message = readString(envelope['message'] ?? envelope['Message']);
      final success = envelope['success'] ?? envelope['Success'];
      if (success == false) {
        return Left(
          Failure.server(
            message: message.isEmpty ? 'Something went wrong.' : message,
            statusCode: res.statusCode,
          ),
        );
      }
      return Right(parse(envelope['data'] ?? envelope['Data'], message));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      // A payload that did not parse. Not the learner's problem to read.
      return Left(Failure.unknown(message: 'Something went wrong. ($e)'));
    }
  }

  static String _path(String template, Map<String, Object> params) {
    var path = template;
    params.forEach((key, value) {
      path = path.replaceAll('{$key}', Uri.encodeComponent(value.toString()));
    });
    return path;
  }

  // ── Catalog ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, StoreHome>> getHome() => _send(
    () => _dio.get(ApiEndpoints.storeHome),
    (data, _) => StoreHome.fromJson(readMap(data)),
  );

  @override
  Future<Either<Failure, StorePage<StoreProductCard>>> getProducts(
    StoreProductQuery query, {
    int pageNo = 1,
    int pageSize = 20,
  }) => _send(
    () => _dio.get(
      ApiEndpoints.storeProducts,
      queryParameters: query.toQuery(pageNo: pageNo, pageSize: pageSize),
    ),
    (data, _) => StorePage.fromJson(readMap(data), StoreProductCard.fromJson),
  );

  @override
  Future<Either<Failure, StoreProductDetail>> getProduct(String productId) =>
      _send(
        () => _dio.get(
          _path(ApiEndpoints.storeProduct, {'productId': productId}),
        ),
        (data, _) => StoreProductDetail.fromJson(readMap(data)),
      );

  @override
  Future<Either<Failure, StorePage<StoreReview>>> getReviews(
    String productId, {
    int pageNo = 1,
    int pageSize = 20,
  }) => _send(
    () => _dio.get(
      _path(ApiEndpoints.storeProductReviews, {'productId': productId}),
      queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
    ),
    (data, _) => StorePage.fromJson(readMap(data), StoreReview.fromJson),
  );

  // ── Addresses ──────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<StoreGstState>>> getStates() async {
    final cached = _states;
    if (cached != null && cached.isNotEmpty) return Right(cached);
    final result = await _send(
      () => _dio.get(ApiEndpoints.storeStates),
      (data, _) => readList(data, StoreGstState.fromJson),
    );
    result.fold((_) {}, (states) => _states = states);
    return result;
  }

  @override
  Future<Either<Failure, List<StoreAddress>>> getAddresses() => _send(
    () => _dio.get(ApiEndpoints.storeAddresses),
    (data, _) => readList(data, StoreAddress.fromJson),
  );

  @override
  Future<Either<Failure, StoreAddress>> saveAddress(
    StoreAddressInput input, {
    int? id,
  }) => _send(
    () => id == null
        ? _dio.post(ApiEndpoints.storeAddresses, data: input.toJson())
        : _dio.put(
            _path(ApiEndpoints.storeAddress, {'id': id}),
            data: input.toJson(),
          ),
    (data, _) => StoreAddress.fromJson(readMap(data)),
  );

  @override
  Future<Either<Failure, Unit>> deleteAddress(int id) => _send(
    () => _dio.delete(_path(ApiEndpoints.storeAddress, {'id': id})),
    (_, _) => unit,
  );

  @override
  Future<Either<Failure, Unit>> makeDefaultAddress(int id) => _send(
    () => _dio.put(_path(ApiEndpoints.storeAddressDefault, {'id': id})),
    (_, _) => unit,
  );

  // ── Cart ───────────────────────────────────────────────────────────

  StoreCart _cart(dynamic data, String _) => data is Map
      ? StoreCart.fromJson(Map<String, dynamic>.from(data))
      : StoreCart.empty;

  @override
  Future<Either<Failure, StoreCart>> getCart() =>
      _send(() => _dio.get(ApiEndpoints.storeCart), _cart);

  @override
  Future<Either<Failure, StoreCart>> setCartQty(String productId, int qty) =>
      _send(
        () => _dio.put(
          _path(ApiEndpoints.storeCartItem, {'productId': productId}),
          data: {'qty': qty},
        ),
        _cart,
      );

  @override
  Future<Either<Failure, StoreCart>> removeFromCart(String productId) async {
    final result = await _send(
      () => _dio.delete(
        _path(ApiEndpoints.storeCartItem, {'productId': productId}),
      ),
      (data, _) => data,
    );
    // The doc promises the K1 shape back from K2 only; re-read when the
    // delete answers with anything else.
    Failure? failure;
    dynamic data;
    result.fold((f) => failure = f, (d) => data = d);
    if (failure != null) return Left(failure!);
    return data is Map ? Right(_cart(data, '')) : getCart();
  }

  @override
  Future<Either<Failure, StoreCart>> clearCart() async {
    final result = await _send(
      () => _dio.delete(ApiEndpoints.storeCart),
      (_, _) => unit,
    );
    return result.map((_) => StoreCart.empty);
  }

  @override
  Future<Either<Failure, int>> getCartCount() => _send(
    () => _dio.get(ApiEndpoints.storeCartCount),
    // Either a bare number or `{ "count": n }`.
    (data, _) => data is Map
        ? readInt(data['count'] ?? data['cartCount'] ?? data['itemCount'])
        : readInt(data),
  );

  // ── Checkout ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, StoreQuote>> quote(
    StoreCheckoutSource source,
    int addressId,
  ) => _send(
    () => _dio.post(ApiEndpoints.storeQuote, data: source.toBody(addressId)),
    (data, _) => StoreQuote.fromJson(readMap(data)),
  );

  @override
  Future<Either<Failure, StorePlacedOrder>> placeOrder(
    StoreCheckoutSource source,
    int addressId,
    String idempotencyKey,
  ) => _send(
    () => _dio.post(
      ApiEndpoints.storeOrders,
      data: {...source.toBody(addressId), 'idempotencyKey': idempotencyKey},
    ),
    (data, _) => StorePlacedOrder.fromJson(readMap(data)),
  );

  @override
  Future<Either<Failure, StoreVerifyResult>> verifyPayment(
    String orderNo, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) => _send(
    () => _dio.post(
      _path(ApiEndpoints.storeVerifyPayment, {'orderNo': orderNo}),
      // Byte-for-byte as Razorpay handed them over.
      data: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    ),
    (data, message) {
      final m = readMap(data);
      return StoreVerifyResult.fromJson({
        'message': message,
        'orderNo': orderNo,
        ...m,
      });
    },
  );

  // ── My orders ──────────────────────────────────────────────────────

  @override
  Future<Either<Failure, StorePage<StoreOrderSummary>>> getOrders(
    StoreOrderGroup group, {
    int pageNo = 1,
    int pageSize = 10,
  }) => _send(
    () => _dio.get(
      ApiEndpoints.storeOrders,
      queryParameters: {
        'group': group.name,
        'pageNo': pageNo,
        'pageSize': pageSize,
      },
    ),
    (data, _) => StorePage.fromJson(readMap(data), StoreOrderSummary.fromJson),
  );

  @override
  Future<Either<Failure, StoreOrderDetail>> getOrder(String orderNo) => _send(
    () => _dio.get(_path(ApiEndpoints.storeOrder, {'orderNo': orderNo})),
    (data, _) => StoreOrderDetail.fromJson(readMap(data)),
  );

  @override
  Future<Either<Failure, String>> cancelOrder(
    String orderNo, {
    String? reason,
  }) => _send(
    () => _dio.post(
      _path(ApiEndpoints.storeCancelOrder, {'orderNo': orderNo}),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    ),
    (_, message) => message.isEmpty
        ? 'Your order has been cancelled. The full amount will be refunded.'
        : message,
  );

  @override
  Future<Either<Failure, String>> confirmReceived(String orderNo) => _send(
    () =>
        _dio.post(_path(ApiEndpoints.storeOrderReceived, {'orderNo': orderNo})),
    (_, message) => message.isEmpty ? 'Thanks for confirming!' : message,
  );

  @override
  Future<Either<Failure, String>> reviewItem(
    String orderNo,
    int itemId, {
    required int rating,
    String? comment,
  }) => _send(
    () => _dio.post(
      _path(ApiEndpoints.storeReviewItem, {
        'orderNo': orderNo,
        'itemId': itemId,
      }),
      data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    ),
    (_, message) => message,
  );
}
