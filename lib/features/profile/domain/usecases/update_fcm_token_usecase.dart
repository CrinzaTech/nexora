import 'package:dartz/dartz.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

/// Syncs the device's FCM token to the backend via the dedicated
/// `PUT /api/v1/update-fcm` endpoint.
///
/// [fcmToken] defaults to the cached value from [SessionService] so
/// callers don't have to thread it through. A null / empty token is a
/// no-op that resolves to success — there's nothing to sync, and the
/// caller (a fire-and-forget background sync) shouldn't treat that as
/// an error.
class UpdateFcmTokenUseCase {
  final ProfileRepository repository;

  UpdateFcmTokenUseCase(this.repository);

  Future<Either<Failure, Unit>> call({String? fcmToken}) {
    final token = fcmToken ?? sl<SessionService>().fcmToken;
    if (token == null || token.isEmpty) {
      return Future.value(const Right(unit));
    }
    return repository.updateFcmToken(token);
  }
}
