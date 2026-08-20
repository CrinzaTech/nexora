import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/notification/data/models/notification_model.dart';

/// Notification repository interface
abstract class NotificationRepository {
  /// Get all notifications for the current user
  Future<Either<Failure, List<NotificationModel>>> getNotifications();

  /// Mark a notification as read.
  ///
  /// `notificationId` is now `int` to match the backend's
  /// `/api/v1/notifications/{notificationId}/read-status` shape.
  Future<Either<Failure, void>> markAsRead(int notificationId);

  /// Clear all notifications (no backend endpoint yet — keeps the existing
  /// stub in place).
  Future<Either<Failure, void>> clearAll();
}
