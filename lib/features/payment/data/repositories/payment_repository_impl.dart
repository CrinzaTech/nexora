import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';
import 'package:nexora/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final ApiClient _apiClient;

  PaymentRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, CreateOrderResponse>> createOrder({
    required int courseId,
    required int priceId,
    String? couponCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'courseId': courseId,
        'priceId': priceId,
      };
      if (couponCode != null && couponCode.isNotEmpty) {
        body['couponCode'] = couponCode;
      }
      final response = await _apiClient.createOrder(body);
      final success = response['success'] as bool? ?? true;
      if (!success) {
        return Left(
          Failure.server(
            message: response['message']?.toString() ?? 'Failed to create order',
          ),
        );
      }
      return Right(CreateOrderResponse.fromJson(response));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, VerifyPaymentResponse>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final body = {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      };
      final response = await _apiClient.verifyPayment(body);
      final success = response['success'] as bool? ?? true;
      if (!success) {
        return Left(
          Failure.server(
            message: response['message']?.toString() ?? 'Payment verification failed',
          ),
        );
      }
      return Right(VerifyPaymentResponse.fromJson(response));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
