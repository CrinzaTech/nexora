/// WHERE the student opened this exam from.
///
/// An exam is one row on the server, but an educator can drop it into course
/// content as many times as they like. Attempts used to be keyed by
/// (exam, student) alone, so submitting an exam in Course A made every other
/// placement report "already submitted" and hand back the Course A score.
/// Sending this context with gate/start/reattempt/history is what keeps each
/// placement's attempts independent.
///
/// [nodeId] is the identity — the curriculum node's own id, which the admin
/// mints uniquely per placement and preserves across saves. It is what tells
/// apart even the same exam added twice into the SAME folder, where
/// [courseId] and [folderPath] would be identical.
///
/// [courseId] and [folderPath] are descriptive only: they ride along so the
/// admin's exam Stats page can show and filter by where a student sat it.
///
/// [standalone] means "no course" — the server treats a missing context that
/// way too, which is why older app builds keep working unchanged.
class ExamContext {
  const ExamContext({this.nodeId, this.courseId, this.folderPath});

  /// Sat outside any course. Sends nothing, so the server falls back to its
  /// own standalone scope.
  static const ExamContext standalone = ExamContext();

  final String? nodeId;
  final int? courseId;
  final String? folderPath;

  bool get isStandalone => nodeId == null || nodeId!.isEmpty;

  /// Query parameters for the GET endpoints (gate, history). Null entries are
  /// stripped by the generated Retrofit client, so a standalone context sends
  /// a plain `?phoneNumber=` exactly as before.
  Map<String, dynamic> toQuery() => isStandalone
      ? const {}
      : {
          'nodeId': nodeId,
          if (courseId != null && courseId! > 0) 'courseId': courseId,
          if (folderPath != null && folderPath!.isNotEmpty)
            'folderPath': folderPath,
        };

  /// Fields merged into the POST bodies (start, reattempt).
  Map<String, dynamic> toBody() => toQuery();
}
