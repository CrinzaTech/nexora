import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/domain/repositories/workshop_pass_repository.dart';

/// Fetches one workshop's entry pass — and, on the first call, issues it.
///
/// Idempotent: the pass number and the QR are frozen server-side at
/// first fetch, so calling this again never mints a second ticket. The
/// artwork *is* rebuilt every time, which is how an organiser restyling
/// their design improves passes already in attendees' hands.
class GetWorkshopPassUseCase {
  final WorkshopPassRepository repository;

  GetWorkshopPassUseCase(this.repository);

  Future<Either<Failure, WorkshopPass>> call(String slug) =>
      repository.getPass(slug);

  /// The locally saved copy, for showing something the instant the
  /// screen opens — and for the door with no signal.
  Future<WorkshopPass?> cached(String slug) => repository.cachedPass(slug);
}
