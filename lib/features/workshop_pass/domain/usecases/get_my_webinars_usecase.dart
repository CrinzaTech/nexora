import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/workshop_pass/data/models/my_webinar_model.dart';
import 'package:nexora/features/workshop_pass/domain/repositories/workshop_pass_repository.dart';

/// Everything this learner booked, past and upcoming.
///
/// The pass endpoints are keyed on a workshop's slug, so without this a
/// pass is only reachable while the app still happens to be holding the
/// slug from a purchase. This is how it stays findable afterwards.
class GetMyWebinarsUseCase {
  final WorkshopPassRepository repository;

  GetMyWebinarsUseCase(this.repository);

  Future<Either<Failure, MyWebinarPage>> call({
    int pageNo = 1,
    int pageSize = 20,
  }) => repository.getMyWebinars(pageNo: pageNo, pageSize: pageSize);
}
