import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/domain/repositories/home_live_repository.dart';

class HomeLiveRepositoryImpl implements HomeLiveRepository {
  final ApiClient _apiClient;

  HomeLiveRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, HomeLiveSessionsPage>> getHomeLiveSessions({
    int pageNo = 1,
    int pageSize = 10,
  }) async {
    try {
      final json = await _apiClient.getHomeLiveSessions(pageNo, pageSize);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Right(HomeLiveSessionsPage(serverTimeUtc: DateTime.now().toUtc()));
      }
      return Right(HomeLiveSessionsPage.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
