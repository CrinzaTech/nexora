import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/domain/repositories/certificate_repository.dart';

/// Every course the learner has finished, each carrying its own
/// `hasCertificate` flag.
class GetCompletedCoursesUseCase {
  final CertificateRepository repository;

  GetCompletedCoursesUseCase(this.repository);

  Future<Either<Failure, List<CompletedCourse>>> call() {
    return repository.getCompletedCourses();
  }
}
