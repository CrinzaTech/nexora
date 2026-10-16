import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/domain/repositories/news_repository.dart';

/// Talks to the News API through the shared [Dio] (auth + 401 renewal come
/// from its interceptor), like the Store repository, rather than adding
/// more hand-maintained stubs to `ApiClient`'s `.g.dart`.
class NewsRepositoryImpl implements NewsRepository {
  final Dio _dio;

  NewsRepositoryImpl(this._dio);

  /// Sends [request] and unwraps `{ success, message, data }`. A
  /// `success: false` on a 2xx is surfaced as a server failure so callers
  /// only branch on one shape.
  Future<Either<Failure, T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final res = await request();
      final body = res.data;
      final envelope = body is Map ? body : const {};
      final success = envelope['success'] ?? envelope['Success'];
      if (success == false) {
        final message = (envelope['message'] ?? envelope['Message'])
            ?.toString();
        return Left(
          Failure.server(
            message: (message == null || message.isEmpty)
                ? 'Something went wrong.'
                : message,
            statusCode: res.statusCode,
          ),
        );
      }
      return Right(parse(envelope['data'] ?? envelope['Data']));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: 'Something went wrong. ($e)'));
    }
  }

  static String _withId(String template, int newsId) =>
      template.replaceAll('{newsId}', '$newsId');

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : const {};

  @override
  Future<Either<Failure, NewsHomeSummary>> getHome() => _send(
    () => _dio.get(ApiEndpoints.newsHome),
    (data) => NewsHomeSummary.fromJson(_map(data)),
  );

  @override
  Future<Either<Failure, NewsPage>> getNews({
    required int pageNo,
    required int pageSize,
  }) => _send(
    () => _dio.get(
      ApiEndpoints.news,
      queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
    ),
    (data) => NewsPage.fromJson(_map(data)),
  );

  @override
  Future<Either<Failure, NewsItem>> getNewsDetail(int newsId) => _send(
    () => _dio.get(_withId(ApiEndpoints.newsDetail, newsId)),
    (data) => NewsItem.fromJson(_map(data)),
  );

  @override
  Future<Either<Failure, void>> markPopupShown(List<int> newsIds) => _send(
    () => _dio.post(ApiEndpoints.newsPopupShown, data: {'newsIds': newsIds}),
    (_) {},
  );

  @override
  Future<Either<Failure, void>> markRead(int newsId) =>
      _send(() => _dio.put(_withId(ApiEndpoints.newsRead, newsId)), (_) {});

  @override
  Future<Either<Failure, void>> markAllRead() =>
      _send(() => _dio.put(ApiEndpoints.newsReadAll), (_) {});
}
