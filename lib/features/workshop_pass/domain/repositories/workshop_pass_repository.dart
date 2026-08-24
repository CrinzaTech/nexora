import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/workshop_pass/data/models/my_webinar_model.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';

abstract class WorkshopPassRepository {
  /// `GET /api/v1/workshop-pass/my` — every webinar and workshop this
  /// learner booked, bought or registered free, past and upcoming.
  ///
  /// There are no business refusals here: a learner with nothing booked
  /// gets an empty 200, not a 404.
  Future<Either<Failure, MyWebinarPage>> getMyWebinars({
    int pageNo = 1,
    int pageSize = 20,
  });

  /// `GET /api/v1/workshop-pass/{slug}` — the pass, ready to display.
  ///
  /// This call is also what **issues** the pass, and it is idempotent:
  /// call it as often as you like, the attendee keeps one pass number.
  /// A successful read is cached, so [cachedPass] can answer offline.
  ///
  /// The refusals are all meaningful and all carry a sentence written
  /// for attendees — 402 (not bought yet), 409 (a workshop that issues
  /// no pass, or a design the organiser has to fix), 404 (no such
  /// workshop for this org). They come back as [Failure.server] with the
  /// status attached so the UI can branch on it.
  Future<Either<Failure, WorkshopPass>> getPass(String slug);

  /// The last pass saved for [slug], or null. Never fails — a cache miss
  /// and an unreadable file are the same answer.
  Future<WorkshopPass?> cachedPass(String slug);

  /// `GET /api/v1/workshop-pass/{slug}/download` — the same pass as a
  /// 720×340pt PDF card, written into the app's documents directory.
  ///
  /// Both endpoints share every check, so **a pass that displays is
  /// always one that can be saved**; there is no "shows but will not
  /// download" case to handle.
  ///
  /// [slug] is only the fallback for composing the URL: the pass carries
  /// an absolute `downloadUrl` and that is what gets used when it is
  /// there.
  Future<Either<Failure, DownloadedPass>> downloadPass({
    required String slug,
    required WorkshopPass pass,
  });
}
