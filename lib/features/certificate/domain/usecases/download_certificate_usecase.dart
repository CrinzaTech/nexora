import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/domain/repositories/certificate_repository.dart';

/// Fetches one course's certificate PDF and saves it to the device.
///
/// The PDF is rebuilt server-side on every request (so template edits by
/// the educator reach certificates already downloaded), but the
/// certificate number and issue date are fixed at the first download.
class DownloadCertificateUseCase {
  final CertificateRepository repository;

  DownloadCertificateUseCase(this.repository);

  Future<Either<Failure, DownloadedCertificate>> call({
    required int courseId,
    required String courseName,
  }) {
    return repository.downloadCertificate(
      courseId: courseId,
      courseName: courseName,
    );
  }
}
