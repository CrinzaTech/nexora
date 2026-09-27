import 'package:nexora/features/webinar/data/models/webinar_lead_model.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';

/// L1 — tell the host's lead report that this learner opened the
/// webinar. See WEBINAR_LEADS_API.md.
///
/// Returns nothing and never fails: the detail screen must not wait on
/// it or show its errors.
class RecordWebinarVisitUseCase {
  final WebinarRepository repository;

  RecordWebinarVisitUseCase(this.repository);

  Future<void> call(String slug, WebinarEntry entry) =>
      repository.recordWebinarVisit(slug, entry: entry);
}
