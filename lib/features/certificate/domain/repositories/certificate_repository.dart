import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';

abstract class CertificateRepository {
  /// `GET /api/v1/certificate/completed` — every course the learner has
  /// finished. An empty list is a normal 200, not an error.
  Future<Either<Failure, List<CompletedCourse>>> getCompletedCourses();

  /// `GET /api/v1/certificate/download/{courseId}` — fetches the PDF and
  /// writes it into the app's documents directory.
  ///
  /// [courseName] never reaches the wire; it's carried through so the
  /// returned model can title the preview screen.
  Future<Either<Failure, DownloadedCertificate>> downloadCertificate({
    required int courseId,
    required String courseName,
  });
}
