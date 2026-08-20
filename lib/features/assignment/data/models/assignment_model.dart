/// Domain model for `GET /api/v1/course/{courseId}/assignment` and the
/// response of `POST /api/v1/course/assignment`.
///
/// Field mapping confirmed against the live API:
///   assignmentTitle        → [title]
///   assignmentFileUrl      → [contentUrl] (questions PDF / image)
///   assignmentStartTime    → [startTime]
///   assignmentEndTime      → [endTime]
///   totalMarks             → [totalMarks]
///   passingMarks           → [passingMarks]
///   submissionId           → [submissionId] (0 = no submission)
///   obtainedMarks          → [grade] (0 = not yet graded; non-zero = graded)
///   submittedFileUrl       → [submissionFileUrl]
///
/// The backend doesn't echo `jsonNodeId` back, so the repository injects
/// it from the request context after parsing.
class Assignment {
  final int assignmentId;
  final int courseId;

  /// Curriculum tree node id (the "JsonNodeId") that anchored this
  /// assignment in the course tree. Sent back on submit. Injected by the
  /// repo because the GET response doesn't include it.
  final String jsonNodeId;

  final String title;

  /// Optional plain-text description. The live API only ships an S3 key
  /// here, so we leave it empty unless a future response surfaces actual
  /// human text — the question paper itself comes from [contentUrl].
  final String description;

  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;

  /// Total marks the assignment is graded out of.
  final double? totalMarks;

  /// Marks needed to pass.
  final double? passingMarks;

  /// Network URL for the question paper / brief. PDF or image.
  final String? contentUrl;

  /// `'pdf'` or `'image'`. Inferred from [contentUrl]'s extension when
  /// the backend doesn't supply it.
  final String? contentType;

  /// `0` when the user hasn't submitted yet; non-zero is the existing
  /// submission's row id.
  final int submissionId;

  final String? submissionFileUrl;
  final DateTime? submittedAt;

  /// `obtainedMarks` from the API. `0` is treated as "submitted but not
  /// yet graded" — see [hasGrade].
  final double? grade;

  /// Optional grader feedback string. Not in the current API; kept on the
  /// model so a future field drops in cleanly.
  final String? feedback;

  const Assignment({
    required this.assignmentId,
    required this.courseId,
    required this.jsonNodeId,
    required this.title,
    required this.description,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.totalMarks,
    this.passingMarks,
    this.contentUrl,
    this.contentType,
    this.submissionId = 0,
    this.submissionFileUrl,
    this.submittedAt,
    this.grade,
    this.feedback,
  });

  /// `true` while the current time is inside `[startTime, endTime]`.
  /// Treats null window edges as open-ended.
  bool get isActive {
    final now = DateTime.now();
    final startsOk = startTime == null || !now.isBefore(startTime!);
    final endsOk = endTime == null || now.isBefore(endTime!);
    return startsOk && endsOk;
  }

  /// Window has closed.
  bool get isExpired {
    final end = endTime;
    return end != null && DateTime.now().isAfter(end);
  }

  bool get hasSubmission => submissionId != 0;

  /// Backend uses `0` for "not graded yet" — only treat positive values
  /// as a real grade. If a course legitimately allows zero marks, swap
  /// this for an explicit `isGraded` flag once the backend exposes one.
  bool get hasGrade => (grade ?? 0) > 0;

  /// User missed the window without submitting — drives the "Did not
  /// attend the assignment" state.
  bool get didNotAttend => isExpired && !hasSubmission;

  /// Lower-cased content type for switch-case branches. Falls back to
  /// inferring from the URL extension when the backend doesn't supply
  /// the field (the live API doesn't yet).
  String get resolvedContentType {
    final raw = contentType?.trim().toLowerCase();
    if (raw != null && raw.isNotEmpty) return raw;
    final url = contentUrl;
    if (url == null || url.isEmpty) return '';
    // Strip query string before sniffing the extension — S3 signed URLs
    // park dozens of params after `?`.
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.pdf')) return 'pdf';
    if (path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif')) {
      return 'image';
    }
    return 'pdf';
  }

  Assignment copyWith({
    int? assignmentId,
    int? courseId,
    String? jsonNodeId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    double? totalMarks,
    double? passingMarks,
    String? contentUrl,
    String? contentType,
    int? submissionId,
    String? submissionFileUrl,
    DateTime? submittedAt,
    double? grade,
    String? feedback,
  }) {
    return Assignment(
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      jsonNodeId: jsonNodeId ?? this.jsonNodeId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      contentUrl: contentUrl ?? this.contentUrl,
      contentType: contentType ?? this.contentType,
      submissionId: submissionId ?? this.submissionId,
      submissionFileUrl: submissionFileUrl ?? this.submissionFileUrl,
      submittedAt: submittedAt ?? this.submittedAt,
      grade: grade ?? this.grade,
      feedback: feedback ?? this.feedback,
    );
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is String && raw.isEmpty) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return Assignment(
      assignmentId: (json['assignmentId'] as num?)?.toInt() ?? 0,
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      // The backend omits jsonNodeId from the GET response — repo layer
      // injects it after parsing using the request's nodeId.
      jsonNodeId:
          (json['jsonNodeId'] ?? json['JsonNodeId'] ?? '').toString(),
      title: (json['assignmentTitle'] ?? json['title'] ?? '').toString(),
      // assignmentInstructions in the live API is an S3 key, not human
      // text. Treat it as empty unless it clearly contains text.
      description: _readDescription(json),
      startTime: parseDate(
        json['assignmentStartTime'] ?? json['startTime'],
      ),
      endTime: parseDate(json['assignmentEndTime'] ?? json['endTime']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      totalMarks: (json['totalMarks'] as num?)?.toDouble(),
      passingMarks: (json['passingMarks'] as num?)?.toDouble(),
      contentUrl: (json['assignmentFileUrl'] ?? json['contentUrl'])
          ?.toString(),
      contentType: (json['contentType'] ?? json['fileType'])?.toString(),
      submissionId: (json['submissionId'] as num?)?.toInt() ?? 0,
      submissionFileUrl: (json['submittedFileUrl'] ??
              json['submissionFileUrl'])
          ?.toString(),
      submittedAt: parseDate(json['submittedAt']),
      grade: (json['obtainedMarks'] as num?)?.toDouble() ??
          (json['grade'] as num?)?.toDouble(),
      feedback: json['feedback']?.toString(),
    );
  }

  /// Human-readable description if the backend ever ships one. The live
  /// API uses `assignmentInstructions` for an S3 key — looks like a path
  /// (contains `/` and ends in a file extension) → discard it.
  static String _readDescription(Map<String, dynamic> json) {
    final raw = (json['description'] ??
            json['assignmentDescription'] ??
            json['assignmentInstructions'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty) return '';
    final looksLikePath = raw.contains('/') &&
        RegExp(r'\.(pdf|png|jpe?g|webp|docx?|gif)$', caseSensitive: false)
            .hasMatch(raw);
    return looksLikePath ? '' : raw;
  }

  /// Resolve the assignment for a given curriculum [nodeId] from a
  /// response whose `data` field can be either a single map or a list.
  /// [nodeId] is also injected onto the resulting model since the live
  /// GET response doesn't echo it back.
  static Assignment? resolve(dynamic data, {String? nodeId}) {
    Assignment hydrate(Map<String, dynamic> map) {
      final parsed = Assignment.fromJson(map);
      if (parsed.jsonNodeId.isNotEmpty) return parsed;
      if (nodeId == null || nodeId.isEmpty) return parsed;
      return parsed.copyWith(jsonNodeId: nodeId);
    }

    if (data is Map<String, dynamic>) return hydrate(data);
    if (data is List) {
      final maps = data.whereType<Map<String, dynamic>>().toList();
      if (maps.isEmpty) return null;
      if (nodeId != null) {
        for (final m in maps) {
          final candidate = Assignment.fromJson(m);
          if (candidate.jsonNodeId == nodeId) return candidate;
        }
      }
      return hydrate(maps.first);
    }
    return null;
  }
}
