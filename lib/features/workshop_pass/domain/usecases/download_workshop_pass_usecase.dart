import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/domain/repositories/workshop_pass_repository.dart';

/// Saves the pass as a PDF card and returns where it landed.
///
/// **Secondary to showing it.** The pass works on screen; saving is for
/// someone who wants it printed, in their gallery, or sent to whoever is
/// driving them there.
class DownloadWorkshopPassUseCase {
  final WorkshopPassRepository repository;

  DownloadWorkshopPassUseCase(this.repository);

  Future<Either<Failure, DownloadedPass>> call({
    required String slug,
    required WorkshopPass pass,
  }) => repository.downloadPass(slug: slug, pass: pass);
}
