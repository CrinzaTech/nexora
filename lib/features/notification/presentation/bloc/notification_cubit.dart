import 'package:nexora/core/bloc/safe_cubit.dart';

import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:nexora/features/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:nexora/features/notification/presentation/bloc/notification_state.dart';

/// Notification cubit
class NotificationCubit extends SafeCubit<NotificationState> {
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationReadUseCase markNotificationRead;

  NotificationCubit({
    required this.getNotifications,
    required this.markNotificationRead,
  }) : super(NotificationState.initial());

  /// Load notifications (initial load — emits `loading` first).
  Future<void> loadNotifications() async {
    emit(NotificationState.loading());
    final result = await getNotifications();
    result.fold(
      (failure) => emit(NotificationState.error(failure.toString())),
      (notifications) => emit(NotificationState.loaded(notifications)),
    );
  }

  /// Pull-to-refresh — re-fetches without dropping to a `loading` state, so
  /// the existing list stays on screen while the spinner is shown by the
  /// `RefreshIndicator`.
  Future<void> refresh() async {
    final result = await getNotifications();
    result.fold(
      (failure) => emit(NotificationState.error(failure.toString())),
      (notifications) => emit(NotificationState.loaded(notifications)),
    );
  }

  /// Optimistically mark a single notification as read in the cubit's
  /// local state, then PUT the read-status update to the backend.
  ///
  /// - No-op if the cubit isn't in `loaded` state.
  /// - Skips both the optimistic flip AND the API call when the
  ///   notification is already `isRead == true`, so re-tapping a read item
  ///   doesn't spam the endpoint.
  /// - On API failure we leave the optimistic state alone (the user has
  ///   already seen the dot disappear); the next refresh will reconcile.
  Future<void> markAsRead(int notificationId) async {
    final current = state.maybeWhen(
      loaded: (list) => list,
      orElse: () => null,
    );
    if (current == null) return;

    final target = current.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw StateError('notification not found'),
    );
    if (target.isRead) return;

    // Optimistic flip — replace the matching item with a copy where
    // isRead is true so the UI updates immediately.
    final updated = current
        .map((n) =>
            n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    emit(NotificationState.loaded(updated));

    final result = await markNotificationRead(notificationId: notificationId);
    result.fold(
      (failure) => Utils.debugLog(
        'NotificationCubit: markAsRead($notificationId) failed — '
        '${failure.message}',
      ),
      (_) {},
    );
  }

  /// Reset state
  void reset() {
    emit(NotificationState.initial());
  }
}
