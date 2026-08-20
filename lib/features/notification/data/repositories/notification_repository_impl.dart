import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/notification/data/models/notification_model.dart';
import 'package:nexora/features/notification/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications() async {
    try {
      final json = await _apiClient.getNotifications();
      final data = json['data'] as List<dynamic>? ?? const [];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(int notificationId) async {
    try {
      await _apiClient.setNotificationReadStatus(notificationId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAll() async {
    // No backend endpoint yet — leave as a no-op until the spec adds one.
    return const Right(null);
  }
}
