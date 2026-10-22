import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/repositories/bundle_repository.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';

/// Raw [Dio], like the Store: seven endpoints of one envelope shape read
/// better through one helper than as hand-written `ApiClient` stubs.
class BundleRepositoryImpl implements BundleRepository {
  final Dio _dio;

  BundleRepositoryImpl(this._dio);

  /// Sends [request] and unwraps `{ success, message, data }`. A
  /// `success: false` on a 2xx surfaces like any other server failure.
  Future<Either<Failure, T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final res = await request();
      final envelope = res.data is Map ? res.data as Map : const {};
      if (envelope['success'] == false) {
        final message = readString(envelope['message']);
        return Left(
          Failure.server(
            message: message.isEmpty ? 'Something went wrong.' : message,
            statusCode: res.statusCode,
          ),
        );
      }
      return Right(parse(envelope['data']));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: 'Something went wrong. ($e)'));
    }
  }

  static String _path(String template, String key, Object value) =>
      template.replaceAll('{$key}', Uri.encodeComponent(value.toString()));

  @override
  Future<Either<Failure, StorePage<BundleCard>>> getBundles({
    int pageNo = 1,
    int pageSize = 10,
  }) => _send(
    () => _dio.get(
      ApiEndpoints.bundles,
      queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
    ),
    (data) => StorePage.fromJson(readMap(data), BundleCard.fromJson),
  );

  @override
  Future<Either<Failure, BundleDetail>> getBundleDetail(int bundleId) async {
    final result = await _send(
      () => _dio.get(_path(ApiEndpoints.bundleDetail, 'bundleId', bundleId)),
      (data) => readMapOrNull(data),
    );
    return result.flatMap((data) {
      if (data == null) {
        return Left(
          Failure.server(message: 'Bundle not found.', statusCode: 404),
        );
      }
      return Right(BundleDetail.fromJson(data));
    });
  }

  @override
  Future<Either<Failure, List<BundleCard>>> getBundlesForCourse(int courseId) =>
      _send(
        () =>
            _dio.get(_path(ApiEndpoints.bundlesByCourse, 'courseId', courseId)),
        (data) => readList(data, BundleCard.fromJson),
      );

  @override
  Future<Either<Failure, BundleOrder>> createBundleOrder(int bundleId) async {
    final result = await _send(
      // No body: the bundle comes from the route and the amount from the
      // database, so there is nothing here for a client to set.
      () => _dio.post(_path(ApiEndpoints.bundleOrder, 'bundleId', bundleId)),
      (data) => BundleOrder.fromJson(readMap(data)),
    );
    return result.flatMap((order) {
      if (!order.isUsable) {
        return Left(
          Failure.server(message: 'Could not start the payment. Try again.'),
        );
      }
      return Right(order);
    });
  }

  @override
  Future<Either<Failure, BundlePaymentResult>> verifyBundlePayment(
    int bundleId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final result = await _send(
      () => _dio.post(
        _path(ApiEndpoints.bundleVerifyPayment, 'bundleId', bundleId),
        // Byte-for-byte as Razorpay sent them: the signature is an HMAC
        // over the other two.
        data: {
          'razorpayOrderId': razorpayOrderId,
          'razorpayPaymentId': razorpayPaymentId,
          'razorpaySignature': razorpaySignature,
        },
      ),
      (data) => readMapOrNull(data),
    );
    return result.map(
      // A 200 we cannot read is the one case where "did the money move?"
      // is genuinely unknown — report it as pending, never as a failure
      // that would invite a second payment.
      (data) => data == null
          ? const BundlePaymentResult(
              paid: false,
              pending: true,
              message: "We're confirming your payment. Do not pay again.",
            )
          : BundlePaymentResult.fromJson(data),
    );
  }

  @override
  Future<Either<Failure, List<StoreProductCard>>> getCourseRelatedProducts(
    int courseId,
  ) => _send(
    () => _dio.get(
      _path(ApiEndpoints.courseRelatedProducts, 'courseId', courseId),
    ),
    (data) => readList(data, StoreProductCard.fromJson),
  );

  @override
  Future<Either<Failure, List<RelatedCourse>>> getProductRelatedCourses(
    String productId,
  ) => _send(
    () => _dio.get(
      _path(ApiEndpoints.storeProductRelatedCourses, 'productId', productId),
    ),
    (data) => readList(data, RelatedCourse.fromJson),
  );
}
