import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/data/models/webinar_payment_model.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';

class WebinarRepositoryImpl implements WebinarRepository {
  final ApiClient _apiClient;

  WebinarRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, WebinarPage>> getWebinars({
    int pageNo = 1,
    int pageSize = 10,
  }) async {
    try {
      final json = await _apiClient.getWebinars(pageNo, pageSize);
      final data = json['data'];
      if (data is! Map<String, dynamic>) return const Right(WebinarPage());
      return Right(WebinarPage.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WebinarDetail>> getWebinarDetail(String slug) async {
    try {
      final json = await _apiClient.getWebinarDetail(slug);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(Failure.server(message: 'This webinar link is not valid.'));
      }
      return Right(WebinarDetail.fromJson(data));
    } on DioException catch (e) {
      return Left(_mapDetailFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WebinarSessionState>> joinWebinar(String slug) async {
    try {
      final json = await _apiClient.joinWebinar(slug);
      return Right(_readSessionState(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WebinarSessionState>> getWebinarState(
    String slug,
  ) async {
    try {
      final json = await _apiClient.getWebinarState(slug);
      return Right(_readSessionState(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getWebinarPlayback(String slug) async {
    try {
      final json = await _apiClient.getWebinarPlayback(slug);
      final data = json['data'];
      final url = data is Map ? data['hlsUrl'] as String? : null;
      if (url == null || url.isEmpty) {
        return Left(
          Failure.server(
            message: 'The stream is not available yet. Please wait.',
          ),
        );
      }
      return Right(url);
    } on DioException catch (e) {
      // 409 / 410 / 403 all arrive here and each means something
      // different to the room — the status code rides along on the
      // Failure so the cubit can go back to polling, show the ended
      // screen, or stop, rather than treating them all as "error".
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LiveChatMessage>>> getWebinarChat(
    String slug, {
    int? beforeId,
    int limit = 30,
  }) async {
    try {
      final json = await _apiClient.getWebinarChat(slug, beforeId, limit);
      // `data` is a bare array here, unlike the object-wrapped payloads
      // on every other webinar endpoint.
      final data = json['data'] as List<dynamic>? ?? const [];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(LiveChatMessage.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getWebinarHubToken(String slug) async {
    try {
      final json = await _apiClient.getWebinarHubToken(slug);
      final data = json['data'];
      final token = data is Map ? data['token'] as String? : null;
      if (token == null || token.isEmpty) {
        return Left(Failure.server(message: 'Could not connect to chat.'));
      }
      return Right(token);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WebinarOrder>> createWebinarOrder(String slug) async {
    try {
      final json = await _apiClient.createWebinarOrder(slug);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(
          Failure.server(message: 'Could not start the payment. Try again.'),
        );
      }
      final order = WebinarOrder.fromJson(data);
      if (!order.isUsable) {
        return Left(
          Failure.server(message: 'Could not start the payment. Try again.'),
        );
      }
      return Right(order);
    } on DioException catch (e) {
      // 400 (free webinar) and 403 (already paid / closed) each mean
      // something specific to the caller, so the status rides along on
      // the Failure rather than being flattened into one message.
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, WebinarPaymentResult>> verifyWebinarPayment(
    String slug, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final json = await _apiClient.verifyWebinarPayment(slug, {
        // Byte-for-byte as Razorpay sent them. No trimming, no casing:
        // the signature is an HMAC over the other two fields.
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        // A 200 we cannot read is the one case where "did the money
        // move?" is genuinely unknown — say so rather than reporting a
        // failure that would invite a second payment.
        return Left(
          Failure.server(
            message:
                "We're confirming your payment. Please refresh in a "
                'moment — do not pay again.',
          ),
        );
      }
      return Right(WebinarPaymentResult.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// A3 and A4 return the same `data` shape; this reads either.
  WebinarSessionState _readSessionState(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return WebinarSessionState(
        status: '',
        canWatch: false,
        startsInSeconds: 0,
        message: '',
        receivedAt: DateTime.now(),
      );
    }
    return WebinarSessionState.fromJson(data);
  }

  /// A 404 on the detail endpoint is not only "unknown slug" — it is
  /// also how the API answers for a webinar belonging to another
  /// organization, and for a link the host has closed. The learner has
  /// nothing to open in any of those cases, so when the backend ships
  /// no sentence of its own they all get the same one instead of the
  /// mapper's generic "Server error (404)".
  Failure _mapDetailFailure(DioException e) {
    final failure = mapDioExceptionToFailure(e);
    final isBareNotFound = failure.maybeWhen(
      server: (message, statusCode) =>
          statusCode == 404 && message.startsWith('Server error'),
      orElse: () => false,
    );
    if (!isBareNotFound) return failure;
    return Failure.server(
      message:
          'This webinar is no longer available. It may have been removed '
          'by the host.',
      statusCode: 404,
    );
  }
}
