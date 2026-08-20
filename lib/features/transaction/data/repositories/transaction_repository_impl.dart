import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/transaction/data/models/receipt_model.dart';
import 'package:nexora/features/transaction/data/models/transaction_model.dart';
import 'package:nexora/features/transaction/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final ApiClient _apiClient;
  final Dio _dio;

  TransactionRepositoryImpl(this._apiClient, this._dio);

  @override
  Future<Either<Failure, List<TransactionModel>>> getHistory({
    String? paymentStatus,
    String? filter,
  }) async {
    try {
      final json = await _apiClient.getTransactionHistory(
        paymentStatus,
        filter,
      );
      final data = json['data'] as List<dynamic>? ?? const [];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(TransactionModel.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReceiptModel>> downloadReceipt(
    int transactionId,
  ) async {
    try {
      final response = await _dio.post<List<int>>(
        ApiEndpoints.receiptDownload,
        data: {'transactionId': transactionId},
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'text/html'},
        ),
      );
      final html = utf8.decode(response.data!);
      final filename =
          _extractFilename(response.headers.value('content-disposition')) ??
          'Receipt_$transactionId.html';
      return Right(ReceiptModel(html: html, filename: filename));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(_decodeErrorBody(e)));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// The error body arrives as raw bytes too (we requested
  /// `ResponseType.bytes` for the HTML success path), so `mapDioExceptionToFailure`
  /// can't read the `{success,message,data}` envelope until it's decoded
  /// back into a Map.
  DioException _decodeErrorBody(DioException e) {
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        e.response!.data = jsonDecode(utf8.decode(data));
      } catch (_) {
        // Not JSON — leave as-is, mapDioExceptionToFailure falls back to
        // the generic "Server error (N)" message.
      }
    }
    return e;
  }

  /// Pulls the filename out of `Content-Disposition: attachment; filename=...`.
  String? _extractFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1);
  }
}
