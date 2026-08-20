import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';

/// Live + upcoming webinars for the learner's organization.
class GetWebinarsUseCase {
  final WebinarRepository repository;

  GetWebinarsUseCase(this.repository);

  Future<Either<Failure, WebinarPage>> call({
    int pageNo = 1,
    int pageSize = 10,
  }) {
    return repository.getWebinars(pageNo: pageNo, pageSize: pageSize);
  }
}
