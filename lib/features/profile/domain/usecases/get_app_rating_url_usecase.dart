import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/profile/data/models/app_rating_url_model.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

/// Fetches the org's "rate this app" store URL from
/// `GET /api/v1/UserAuth/app-rating-url`.
class GetAppRatingUrlUseCase {
  final ProfileRepository _repository;

  GetAppRatingUrlUseCase(this._repository);

  /// [deviceType] must be `"android"` or `"ios"`.
  Future<Either<Failure, AppRatingUrlModel>> call(String deviceType) {
    return _repository.getAppRatingUrl(deviceType);
  }
}
