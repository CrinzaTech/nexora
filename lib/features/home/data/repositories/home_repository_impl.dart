import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:nexora/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final ApiClient apiClient;

  HomeRepositoryImpl(this.apiClient);

  @override
  Future<Either<Failure, DashboardData>> getDashboard() async {
    try {
      final response = await apiClient.getDashboard();
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      return Right(DashboardData.fromJson(data));
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to load dashboard',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
