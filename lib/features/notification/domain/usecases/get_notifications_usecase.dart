import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/notification/data/models/notification_model.dart';
import 'package:nexora/features/notification/domain/repositories/notification_repository.dart';

/// Get all notifications use case
class GetNotificationsUseCase {
  final NotificationRepository repository;

  const GetNotificationsUseCase(this.repository);

  Future<Either<Failure, List<NotificationModel>>> call() async {
    return await repository.getNotifications();
  }
}
