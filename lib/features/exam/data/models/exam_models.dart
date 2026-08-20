/// Domain models for the student exam-taking flow (`api/v1/exam`).
///
/// Shapes mirror EXAM_API.md. All success responses are wrapped in a
/// `{ success, message, data }` envelope — these models parse the `data`
/// payload only; the repository unwraps the envelope.
library;

// ─────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────

/// Gate state returned by `/gate` and `/start`.
enum ExamGateState {
  notFound,
  notPublished,
  notStarted,
  ended,
  open,
  unknown;

  static ExamGateState fromString(String? raw) {
    switch (raw?.trim()) {
      case 'notFound':
        return ExamGateState.notFound;
      case 'notPublished':
        return ExamGateState.notPublished;
      case 'notStarted':
        return ExamGateState.notStarted;
      case 'ended':
        return ExamGateState.ended;
      case 'open':
        return ExamGateState.open;
      default:
        return ExamGateState.unknown;
    }
  }
}

/// Question type discriminator. Only the fields matching the type are
/// meaningful on [ExamQuestion] (see EXAM_API.md "Shared shapes").
enum ExamQuestionType {
  multipleChoice,
  multipleSelect,
  integer,
  trueFalse,
  fillUps,
  matchTheColumn,
  comprehension,
  unknown;

  static ExamQuestionType fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'multiple_choice':
        return ExamQuestionType.multipleChoice;
      case 'multiple_select':
        return ExamQuestionType.multipleSelect;
      case 'integer':
        return ExamQuestionType.integer;
      case 'true_false':
        return ExamQuestionType.trueFalse;
      case 'fill_ups':
        return ExamQuestionType.fillUps;
      case 'match_the_column':
        return ExamQuestionType.matchTheColumn;
      case 'comprehension':
        return ExamQuestionType.comprehension;
      default:
        return ExamQuestionType.unknown;
    }
  }
}

/// Which keypad an exam offers. Only meaningful when the exam's
/// `allowCalculator` is true — the server stores the type even while the
/// flag is off (so an admin who unticks and re-ticks the box gets their
/// choice back), so `allowCalculator: false` with `calculatorType:
/// scientific` is a normal state meaning "no calculator". Never infer
/// availability from the type.
enum ExamCalculatorType {
  simple,
  scientific;

  static ExamCalculatorType fromString(String? raw) {
    return raw?.trim().toLowerCase() == 'scientific'
        ? ExamCalculatorType.scientific
        : ExamCalculatorType.simple;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared parse helpers
// ─────────────────────────────────────────────────────────────────────────

/// Parses a UTC timestamp that may arrive without a timezone designator
/// (e.g. `2026-07-19T10:45:00`). The API names these fields `*Utc`, so a
/// bare value is interpreted as UTC (a trailing `Z` is appended) and
/// returned as a UTC [DateTime]. Callers convert to local for display.
DateTime? parseExamUtc(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final hasZone = s.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  final normalised = hasZone ? s : '${s}Z';
  return DateTime.tryParse(normalised)?.toUtc();
}

int? _asInt(dynamic v) => (v as num?)?.toInt();
double? _asDouble(dynamic v) => (v as num?)?.toDouble();

List<int> _asIntList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toList(growable: false);
  }
  return const [];
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').toList(growable: false);
  }
  return const [];
}

/// Maps whose keys are 1-based indices sent as strings on the wire, parsed
/// into an `int → value` map: `savedBlanks` / `blankAnswers` (blank index →
/// text) and `savedMatches` / `matchAnswers` (Column A row → token).
Map<int, String> _asIntKeyedMap(dynamic v) {
  final out = <int, String>{};
  if (v is Map) {
    v.forEach((key, value) {
      final idx = int.tryParse(key.toString());
      if (idx != null) out[idx] = value?.toString() ?? '';
    });
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────
// Attempt state (gate / start / reattempt)
// ─────────────────────────────────────────────────────────────────────────

class AttemptStateResponse {
  final ExamGateState gateState;
  final int examId;
  final String examTitle;

  /// `normal` or `competitive`. This app only supports `normal`.
  final String examMode;

  final bool hasInstructions;
  final String? instructions;
  final int? durationMinutes;

  /// Whether an on-screen calculator is offered for this exam, and which
  /// keypad. Present on the gate so the instructions screen can say so
  /// *before* the clock starts. Read-only — nothing is posted back.
  final bool allowCalculator;
  final ExamCalculatorType calculatorType;

  /// Populated when an `in_progress` attempt already exists (resume case)
  /// or after `/start`.
  final int? attemptId;
  final String? attemptStatus;
  final int? currentQuestionIndex;
  final DateTime? deadlineUtc;

  final int attemptsUsed;
  final int maxAttempts;
  final bool exhausted;

  /// Populated when the student has a previously graded attempt (for the
  /// "you scored X, want to try again?" affordance) even if not exhausted.
  final int? lastEvaluatedAttemptId;
  final double? lastEvaluatedScore;
  final double? lastEvaluatedMaxScore;
  final bool? lastEvaluatedIsPassed;

  const AttemptStateResponse({
    required this.gateState,
    required this.examId,
    required this.examTitle,
    required this.examMode,
    required this.hasInstructions,
    this.instructions,
    this.durationMinutes,
    this.allowCalculator = false,
    this.calculatorType = ExamCalculatorType.simple,
    this.attemptId,
    this.attemptStatus,
    this.currentQuestionIndex,
    this.deadlineUtc,
    this.attemptsUsed = 0,
    this.maxAttempts = 1,
    this.exhausted = false,
    this.lastEvaluatedAttemptId,
    this.lastEvaluatedScore,
    this.lastEvaluatedMaxScore,
    this.lastEvaluatedIsPassed,
  });

  bool get isCompetitive => examMode.trim().toLowerCase() == 'competitive';
  bool get isOpen => gateState == ExamGateState.open;
  bool get hasInProgressAttempt =>
      attemptId != null && (attemptStatus ?? '') == 'in_progress';
  bool get hasLastEvaluated => lastEvaluatedAttemptId != null;
  bool get canReattempt => !exhausted && attemptsUsed < maxAttempts;

  factory AttemptStateResponse.fromJson(Map<String, dynamic> json) {
    return AttemptStateResponse(
      gateState: ExamGateState.fromString(json['gateState']?.toString()),
      examId: _asInt(json['examId']) ?? 0,
      examTitle: (json['examTitle'] ?? '').toString(),
      examMode: (json['examMode'] ?? 'normal').toString(),
      hasInstructions: json['hasInstructions'] == true,
      instructions: json['instructions']?.toString(),
      durationMinutes: _asInt(json['durationMinutes']),
      allowCalculator: json['allowCalculator'] == true,
      calculatorType: ExamCalculatorType.fromString(
        json['calculatorType']?.toString(),
      ),
      attemptId: _asInt(json['attemptId']),
      attemptStatus: json['attemptStatus']?.toString(),
      currentQuestionIndex: _asInt(json['currentQuestionIndex']),
      deadlineUtc: parseExamUtc(json['deadlineUtc']),
      attemptsUsed: _asInt(json['attemptsUsed']) ?? 0,
      maxAttempts: _asInt(json['maxAttempts']) ?? 1,
      exhausted: json['exhausted'] == true,
      lastEvaluatedAttemptId: _asInt(json['lastEvaluatedAttemptId']),
      lastEvaluatedScore: _asDouble(json['lastEvaluatedScore']),
      lastEvaluatedMaxScore: _asDouble(json['lastEvaluatedMaxScore']),
      lastEvaluatedIsPassed: json['lastEvaluatedIsPassed'] as bool?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Paper (normal mode)
// ─────────────────────────────────────────────────────────────────────────

class ExamPaperResponse {
  final int examId;
  final String examTitle;
  final int attemptId;
  final bool hasInstructions;
  final String? instructions;
  final int? durationMinutes;
  final DateTime? deadlineUtc;

  /// Repeated from the gate so an app resuming straight into a paper
  /// (deep link, restart mid-attempt) never has to have called `/gate`.
  final bool allowCalculator;
  final ExamCalculatorType calculatorType;

  final List<ExamSection> sections;

  const ExamPaperResponse({
    required this.examId,
    required this.examTitle,
    required this.attemptId,
    required this.hasInstructions,
    this.instructions,
    this.durationMinutes,
    this.deadlineUtc,
    this.allowCalculator = false,
    this.calculatorType = ExamCalculatorType.simple,
    this.sections = const [],
  });

  /// Flat list of top-level (non-child) questions, used for numbering and
  /// total counts.
  List<ExamQuestion> get allQuestions =>
      sections.expand((s) => s.questions).toList(growable: false);

  int get totalQuestions => allQuestions.length;
  int get totalMarks => allQuestions.fold<double>(0, (sum, q) => sum + q.totalMarksRollup).round();

  factory ExamPaperResponse.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return ExamPaperResponse(
      examId: _asInt(json['examId']) ?? 0,
      examTitle: (json['examTitle'] ?? '').toString(),
      attemptId: _asInt(json['attemptId']) ?? 0,
      hasInstructions: json['hasInstructions'] == true,
      instructions: json['instructions']?.toString(),
      durationMinutes: _asInt(json['durationMinutes']),
      deadlineUtc: parseExamUtc(json['deadlineUtc']),
      allowCalculator: json['allowCalculator'] == true,
      calculatorType: ExamCalculatorType.fromString(
        json['calculatorType']?.toString(),
      ),
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(ExamSection.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class ExamSection {
  final String name;
  final String? instructions;
  final List<ExamQuestion> questions;

  const ExamSection({
    required this.name,
    this.instructions,
    this.questions = const [],
  });

  factory ExamSection.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    return ExamSection(
      name: (json['name'] ?? '').toString(),
      instructions: json['instructions']?.toString(),
      questions: rawQuestions is List
          ? rawQuestions
              .whereType<Map<String, dynamic>>()
              .map(ExamQuestion.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

/// Pre-submit question shape. **Never contains a correct-answer field.**
class ExamQuestion {
  final int id;
  final ExamQuestionType questionType;
  final String questionText;
  final double positiveMarks;
  final double negativeMarks;
  final double unattemptedNegativeMarks;
  final String? difficulty;
  final String? subjectName;
  final String? topicName;

  final List<int> optionIds;
  final List<String> optionTexts;
  final int blankCount;

  /// `match_the_column` — Column A prompts, in server order. The 1-based
  /// row number is `index + 1`; that number is what the answer is keyed by.
  final List<String> matchLeftTexts;

  /// `match_the_column` — Column B display texts. Shuffled server-side
  /// (stable within an attempt) and usually LONGER than Column A: the
  /// extras are distractors, indistinguishable by design. Parallel to
  /// [matchRightTokens] — never index it by a Column A row.
  final List<String> matchRightTexts;

  /// `match_the_column` — opaque token per Column B entry. This is what
  /// gets posted as the answer; the index and the text never are.
  final List<String> matchRightTokens;

  /// Nested sub-questions for `comprehension`. Each child is a full
  /// question (never itself `comprehension`).
  final List<ExamQuestion> children;

  // Autosaved / repainted answers.
  final int? savedOptionId;
  final List<int> savedOptionIds;
  final int? savedInteger;
  final bool? savedBoolean;
  final Map<int, String> savedBlanks;

  /// `match_the_column` — 1-based Column A row → the token chosen for it.
  /// Only rows the student actually answered are present.
  final Map<int, String> savedMatches;

  const ExamQuestion({
    required this.id,
    required this.questionType,
    required this.questionText,
    this.positiveMarks = 0,
    this.negativeMarks = 0,
    this.unattemptedNegativeMarks = 0,
    this.difficulty,
    this.subjectName,
    this.topicName,
    this.optionIds = const [],
    this.optionTexts = const [],
    this.blankCount = 0,
    this.matchLeftTexts = const [],
    this.matchRightTexts = const [],
    this.matchRightTokens = const [],
    this.children = const [],
    this.savedOptionId,
    this.savedOptionIds = const [],
    this.savedInteger,
    this.savedBoolean,
    this.savedBlanks = const {},
    this.savedMatches = const {},
  });

  bool get isComprehension => questionType == ExamQuestionType.comprehension;

  bool get isMatchTheColumn => questionType == ExamQuestionType.matchTheColumn;

  /// Column B zipped into (token, text) pairs, in the server's order.
  /// Defensively clamped to the shorter of the two arrays — they are
  /// documented to be the same length, but a mismatch must not crash.
  List<ExamMatchOption> get matchOptions {
    final count = matchRightTexts.length < matchRightTokens.length
        ? matchRightTexts.length
        : matchRightTokens.length;
    return List.generate(
      count,
      (i) => ExamMatchOption(
        token: matchRightTokens[i],
        text: matchRightTexts[i],
      ),
      growable: false,
    );
  }

  /// [savedMatches] with anything unusable dropped: rows outside Column A
  /// and tokens no longer in Column B (the examiner may have edited the
  /// question since the answer was saved). Those are treated as "no
  /// selection" rather than crashing or painting a blank chip.
  Map<int, String> get validSavedMatches {
    if (savedMatches.isEmpty) return const {};
    final tokens = matchRightTokens.toSet();
    final out = <int, String>{};
    savedMatches.forEach((row, token) {
      if (row >= 1 && row <= matchLeftTexts.length && tokens.contains(token)) {
        out[row] = token;
      }
    });
    return out;
  }

  /// Total positive marks including children (for comprehension roll-up).
  double get totalMarksRollup => isComprehension
      ? children.fold<double>(0, (sum, c) => sum + c.positiveMarks)
      : positiveMarks;

  /// Builds the initial in-progress draft from any autosaved answer so the
  /// UI repaints where the student left off.
  ExamAnswerDraft toInitialDraft() => ExamAnswerDraft(
        optionId: savedOptionId,
        optionIds: List<int>.from(savedOptionIds),
        integer: savedInteger,
        boolean: savedBoolean,
        blanks: Map<int, String>.from(savedBlanks),
        matches: Map<int, String>.from(validSavedMatches),
      );

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return ExamQuestion(
      id: _asInt(json['id']) ?? 0,
      questionType: ExamQuestionType.fromString(json['questionType']?.toString()),
      questionText: (json['questionText'] ?? '').toString(),
      positiveMarks: _asDouble(json['positiveMarks']) ?? 0,
      negativeMarks: _asDouble(json['negativeMarks']) ?? 0,
      unattemptedNegativeMarks:
          _asDouble(json['unattemptedNegativeMarks']) ?? 0,
      difficulty: json['difficulty']?.toString(),
      subjectName: json['subjectName']?.toString(),
      topicName: json['topicName']?.toString(),
      optionIds: _asIntList(json['optionIds']),
      optionTexts: _asStringList(json['optionTexts']),
      blankCount: _asInt(json['blankCount']) ?? 0,
      matchLeftTexts: _asStringList(json['matchLeftTexts']),
      matchRightTexts: _asStringList(json['matchRightTexts']),
      matchRightTokens: _asStringList(json['matchRightTokens']),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(ExamQuestion.fromJson)
              .toList(growable: false)
          : const [],
      savedOptionId: _asInt(json['savedOptionId']),
      savedOptionIds: _asIntList(json['savedOptionIds']),
      savedInteger: _asInt(json['savedInteger']),
      savedBoolean: json['savedBoolean'] as bool?,
      savedBlanks: _asIntKeyedMap(json['savedBlanks']),
      savedMatches: _asIntKeyedMap(json['savedMatches']),
    );
  }
}

/// One Column B entry of a `match_the_column` question: the text the
/// student reads, and the opaque token that identifies it on the wire.
class ExamMatchOption {
  final String token;
  final String text;

  const ExamMatchOption({required this.token, required this.text});
}

// ─────────────────────────────────────────────────────────────────────────
// Competitive mode (one question at a time)
// ─────────────────────────────────────────────────────────────────────────

/// Response of `GET /attempt/{attemptId}/question` — the current question
/// in competitive mode. Fetching stamps the server-side `shown_at` timer
/// (idempotent), so the server can compute time-spent from it on answer.
class CompetitiveQuestionResponse {
  final bool finished;
  final int examId;
  final String examTitle;
  final String? sectionName;
  final String? sectionInstructions;

  /// The current question (null when [finished]).
  final ExamQuestion? question;

  final int questionNumber;
  final int totalQuestions;
  final bool isLast;
  final bool willChangeSection;
  final String? nextSectionName;
  final DateTime? deadlineUtc;

  /// Competitive mode re-fetches per question, so the flags come back on
  /// every question — including the `finished: true` response. Read them
  /// from the response being rendered rather than a cached copy: an admin
  /// can flip the setting mid-attempt.
  final bool allowCalculator;
  final ExamCalculatorType calculatorType;

  const CompetitiveQuestionResponse({
    required this.finished,
    required this.examId,
    required this.examTitle,
    this.sectionName,
    this.sectionInstructions,
    this.question,
    this.questionNumber = 0,
    this.totalQuestions = 0,
    this.isLast = false,
    this.willChangeSection = false,
    this.nextSectionName,
    this.deadlineUtc,
    this.allowCalculator = false,
    this.calculatorType = ExamCalculatorType.simple,
  });

  factory CompetitiveQuestionResponse.fromJson(Map<String, dynamic> json) {
    final rawQuestion = json['question'];
    return CompetitiveQuestionResponse(
      finished: json['finished'] == true,
      examId: _asInt(json['examId']) ?? 0,
      examTitle: (json['examTitle'] ?? '').toString(),
      sectionName: json['sectionName']?.toString(),
      sectionInstructions: json['sectionInstructions']?.toString(),
      question: rawQuestion is Map<String, dynamic>
          ? ExamQuestion.fromJson(rawQuestion)
          : null,
      questionNumber: _asInt(json['questionNumber']) ?? 0,
      totalQuestions: _asInt(json['totalQuestions']) ?? 0,
      isLast: json['isLast'] == true,
      willChangeSection: json['willChangeSection'] == true,
      nextSectionName: json['nextSectionName']?.toString(),
      deadlineUtc: parseExamUtc(json['deadlineUtc']),
      allowCalculator: json['allowCalculator'] == true,
      calculatorType: ExamCalculatorType.fromString(
        json['calculatorType']?.toString(),
      ),
    );
  }
}

/// Response of `POST /attempt/{attemptId}/answer` — the outcome of
/// recording one competitive answer and advancing.
class CompetitiveAnswerResultResponse {
  final bool finished;

  /// `false` means the deadline had already passed when this landed —
  /// nothing was recorded; the client should submit.
  final bool accepted;
  final bool willChangeSection;
  final String? fromSectionName;
  final String? nextSectionName;
  final DateTime? deadlineUtc;

  const CompetitiveAnswerResultResponse({
    required this.finished,
    required this.accepted,
    this.willChangeSection = false,
    this.fromSectionName,
    this.nextSectionName,
    this.deadlineUtc,
  });

  factory CompetitiveAnswerResultResponse.fromJson(Map<String, dynamic> json) {
    return CompetitiveAnswerResultResponse(
      finished: json['finished'] == true,
      accepted: json['accepted'] == true,
      willChangeSection: json['willChangeSection'] == true,
      fromSectionName: json['fromSectionName']?.toString(),
      nextSectionName: json['nextSectionName']?.toString(),
      deadlineUtc: parseExamUtc(json['deadlineUtc']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Answer draft (client-side, in-progress) + wire request
// ─────────────────────────────────────────────────────────────────────────

/// Local, mutable-by-copy holder for one question's in-progress answer.
/// The cubit keeps a `Map<int questionId, ExamAnswerDraft>`. Serialised to
/// the `StudentAnswerRequest` shape for save/submit.
class ExamAnswerDraft {
  final int? optionId; // multiple_choice
  final List<int> optionIds; // multiple_select
  final int? integer; // integer
  final bool? boolean; // true_false
  final Map<int, String> blanks; // fill_ups (1-based index → text)

  /// match_the_column (1-based Column A row → Column B token). Only rows
  /// the student answered are present; clearing a row removes its key.
  final Map<int, String> matches;

  const ExamAnswerDraft({
    this.optionId,
    this.optionIds = const [],
    this.integer,
    this.boolean,
    this.blanks = const {},
    this.matches = const {},
  });

  ExamAnswerDraft copyWith({
    int? optionId,
    List<int>? optionIds,
    int? integer,
    bool? boolean,
    Map<int, String>? blanks,
    Map<int, String>? matches,
    bool clearOptionId = false,
    bool clearInteger = false,
    bool clearBoolean = false,
  }) {
    return ExamAnswerDraft(
      optionId: clearOptionId ? null : (optionId ?? this.optionId),
      optionIds: optionIds ?? this.optionIds,
      integer: clearInteger ? null : (integer ?? this.integer),
      boolean: clearBoolean ? null : (boolean ?? this.boolean),
      blanks: blanks ?? this.blanks,
      matches: matches ?? this.matches,
    );
  }

  /// Row → token with unanswered rows dropped. This is the `matchAnswers`
  /// wire shape (string keys, as JSON object keys always are), and the
  /// same filter decides whether the question counts as answered. Emitted
  /// in row order so the payload doesn't depend on tap order.
  Map<String, String> get matchAnswersJson {
    final rows = matches.keys.toList()..sort();
    final out = <String, String>{};
    for (final row in rows) {
      final token = matches[row] ?? '';
      if (token.trim().isNotEmpty) out[row.toString()] = token;
    }
    return out;
  }

  /// True when nothing has been entered for this question.
  bool get isEmpty =>
      optionId == null &&
      optionIds.isEmpty &&
      integer == null &&
      boolean == null &&
      blanks.values.every((v) => v.trim().isEmpty) &&
      matchAnswersJson.isEmpty;

  /// Serialise to the `StudentAnswerRequest` wire shape. Only the field(s)
  /// relevant to [type] are set; the rest are omitted.
  Map<String, dynamic>? toRequestJson(int questionId, ExamQuestionType type) {
    final map = <String, dynamic>{'questionId': questionId};
    switch (type) {
      case ExamQuestionType.multipleChoice:
        if (optionId == null) return null;
        map['selectedOptionId'] = optionId;
      case ExamQuestionType.multipleSelect:
        if (optionIds.isEmpty) return null;
        map['selectedOptionIds'] = optionIds;
      case ExamQuestionType.integer:
        if (integer == null) return null;
        map['answerInteger'] = integer;
      case ExamQuestionType.trueFalse:
        if (boolean == null) return null;
        map['answerBoolean'] = boolean;
      case ExamQuestionType.fillUps:
        final filled = <String, String>{};
        blanks.forEach((k, v) {
          if (v.trim().isNotEmpty) filled[k.toString()] = v;
        });
        if (filled.isEmpty) return null;
        map['blankAnswers'] = filled;
      case ExamQuestionType.matchTheColumn:
        // Only answered rows are posted — an absent row is how
        // "unanswered" is expressed. Never a null or empty value.
        final picked = matchAnswersJson;
        if (picked.isEmpty) return null;
        map['matchAnswers'] = picked;
      case ExamQuestionType.comprehension:
      case ExamQuestionType.unknown:
        return null; // parents/unknowns carry no answer
    }
    return map;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Save progress
// ─────────────────────────────────────────────────────────────────────────

class SaveProgressResponse {
  final bool ok;
  final String message;

  const SaveProgressResponse({required this.ok, this.message = ''});

  factory SaveProgressResponse.fromJson(Map<String, dynamic> json) {
    return SaveProgressResponse(
      ok: json['ok'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Result
// ─────────────────────────────────────────────────────────────────────────

class ExamResultResponse {
  final int attemptId;
  final String examTitle;
  final bool resultsVisible;
  final String resultReleaseMode; // instant | scheduled | disabled
  final DateTime? resultsAvailableAt;

  final double? score;
  final double? maxScore;
  final double? percentage;
  final bool? isPassed;
  final int? correctCount;
  final int? wrongCount;
  final int? skippedCount;
  final int attemptsUsed;
  final int maxAttempts;
  final bool isCompetitive;

  final List<ExamResultSection> sections;

  const ExamResultResponse({
    required this.attemptId,
    required this.examTitle,
    required this.resultsVisible,
    this.resultReleaseMode = 'instant',
    this.resultsAvailableAt,
    this.score,
    this.maxScore,
    this.percentage,
    this.isPassed,
    this.correctCount,
    this.wrongCount,
    this.skippedCount,
    this.attemptsUsed = 0,
    this.maxAttempts = 1,
    this.isCompetitive = false,
    this.sections = const [],
  });

  bool get hasAttemptsLeft => attemptsUsed < maxAttempts;

  factory ExamResultResponse.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return ExamResultResponse(
      attemptId: _asInt(json['attemptId']) ?? 0,
      examTitle: (json['examTitle'] ?? '').toString(),
      resultsVisible: json['resultsVisible'] == true,
      resultReleaseMode: (json['resultReleaseMode'] ?? 'instant').toString(),
      resultsAvailableAt: parseExamUtc(json['resultsAvailableAt']),
      score: _asDouble(json['score']),
      maxScore: _asDouble(json['maxScore']),
      percentage: _asDouble(json['percentage']),
      isPassed: json['isPassed'] as bool?,
      correctCount: _asInt(json['correctCount']),
      wrongCount: _asInt(json['wrongCount']),
      skippedCount: _asInt(json['skippedCount']),
      attemptsUsed: _asInt(json['attemptsUsed']) ?? 0,
      maxAttempts: _asInt(json['maxAttempts']) ?? 1,
      isCompetitive: json['isCompetitive'] == true,
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(ExamResultSection.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class ExamResultSection {
  final String name;
  final List<ExamResultQuestion> questions;

  const ExamResultSection({required this.name, this.questions = const []});

  factory ExamResultSection.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    return ExamResultSection(
      name: (json['name'] ?? '').toString(),
      questions: rawQuestions is List
          ? rawQuestions
              .whereType<Map<String, dynamic>>()
              .map(ExamResultQuestion.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class ExamResultQuestion {
  final int id;
  final ExamQuestionType questionType;
  final String questionText;
  final String? solutionText;
  final double positiveMarks;
  final double negativeMarks;
  final double marksAwarded;
  final bool? isCorrect;
  final bool isPartial;
  final int? timeTakenSeconds;

  final List<ExamResultOption> options;
  final int? correctInteger;
  final int? studentInteger;
  final bool? correctBoolean;
  final bool? studentBoolean;
  final List<ExamResultBlank> blanks;

  /// `match_the_column` — one entry per Column A PROMPT (never per Column B
  /// option). Its length is the divisor the partial score was computed
  /// with. Column B itself is not returned; it isn't needed here.
  final List<ExamResultMatchRow> matchRows;

  final List<ExamResultQuestion> children;

  const ExamResultQuestion({
    required this.id,
    required this.questionType,
    required this.questionText,
    this.solutionText,
    this.positiveMarks = 0,
    this.negativeMarks = 0,
    this.marksAwarded = 0,
    this.isCorrect,
    this.isPartial = false,
    this.timeTakenSeconds,
    this.options = const [],
    this.correctInteger,
    this.studentInteger,
    this.correctBoolean,
    this.studentBoolean,
    this.blanks = const [],
    this.matchRows = const [],
    this.children = const [],
  });

  bool get isComprehension => questionType == ExamQuestionType.comprehension;

  /// Whether the student left this unanswered (drives the "Skipped" pill).
  bool get isSkipped {
    switch (questionType) {
      case ExamQuestionType.multipleChoice:
      case ExamQuestionType.multipleSelect:
        return !options.any((o) => o.isSelected);
      case ExamQuestionType.integer:
        return studentInteger == null;
      case ExamQuestionType.trueFalse:
        return studentBoolean == null;
      case ExamQuestionType.fillUps:
        return blanks.every((b) => (b.studentText ?? '').trim().isEmpty);
      case ExamQuestionType.matchTheColumn:
        // A row is blank only when studentRightText is null — a wrong pick
        // still resolves to the text the student chose.
        return matchRows.every((r) => (r.studentRightText ?? '').trim().isEmpty);
      case ExamQuestionType.comprehension:
        return children.every((c) => c.isSkipped);
      case ExamQuestionType.unknown:
        return false;
    }
  }

  factory ExamResultQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final rawBlanks = json['blanks'];
    final rawMatchRows = json['matchRows'];
    final rawChildren = json['children'];
    return ExamResultQuestion(
      id: _asInt(json['id']) ?? 0,
      questionType: ExamQuestionType.fromString(json['questionType']?.toString()),
      questionText: (json['questionText'] ?? '').toString(),
      solutionText: json['solutionText']?.toString(),
      positiveMarks: _asDouble(json['positiveMarks']) ?? 0,
      negativeMarks: _asDouble(json['negativeMarks']) ?? 0,
      marksAwarded: _asDouble(json['marksAwarded']) ?? 0,
      isCorrect: json['isCorrect'] as bool?,
      isPartial: json['isPartial'] == true,
      timeTakenSeconds: _asInt(json['timeTakenSeconds']),
      options: rawOptions is List
          ? rawOptions
              .whereType<Map<String, dynamic>>()
              .map(ExamResultOption.fromJson)
              .toList(growable: false)
          : const [],
      correctInteger: _asInt(json['correctInteger']),
      studentInteger: _asInt(json['studentInteger']),
      correctBoolean: json['correctBoolean'] as bool?,
      studentBoolean: json['studentBoolean'] as bool?,
      blanks: rawBlanks is List
          ? rawBlanks
              .whereType<Map<String, dynamic>>()
              .map(ExamResultBlank.fromJson)
              .toList(growable: false)
          : const [],
      matchRows: rawMatchRows is List
          ? rawMatchRows
              .whereType<Map<String, dynamic>>()
              .map(ExamResultMatchRow.fromJson)
              .toList(growable: false)
          : const [],
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(ExamResultQuestion.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class ExamResultOption {
  final int id;
  final String text;
  final bool isCorrect;
  final bool isSelected;

  const ExamResultOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
    this.isSelected = false,
  });

  factory ExamResultOption.fromJson(Map<String, dynamic> json) {
    return ExamResultOption(
      id: _asInt(json['id']) ?? 0,
      text: (json['text'] ?? '').toString(),
      isCorrect: json['isCorrect'] == true,
      isSelected: json['isSelected'] == true,
    );
  }
}

/// One blank in a `fill_ups` result. The backend shape isn't strictly
/// documented, so keys are read defensively.
class ExamResultBlank {
  /// 1-based blank index / label.
  final int index;
  final String? studentText;

  /// Human-readable accepted answers (e.g. "H2O, h2o" or "99.0000 - 101.0000").
  final String? acceptedText;
  final bool? isCorrect;

  const ExamResultBlank({
    required this.index,
    this.studentText,
    this.acceptedText,
    this.isCorrect,
  });

  factory ExamResultBlank.fromJson(Map<String, dynamic> json) {
    // Accepted answers may arrive as a list or a single string.
    final rawAccepted =
        json['accepted'] ?? json['acceptedAnswers'] ?? json['correctText'];
    String? accepted;
    if (rawAccepted is List) {
      accepted = rawAccepted.map((e) => e?.toString() ?? '').join(', ');
    } else if (rawAccepted != null) {
      accepted = rawAccepted.toString();
    }
    return ExamResultBlank(
      index: _asInt(json['index']) ?? _asInt(json['blankIndex']) ?? 0,
      studentText:
          (json['studentText'] ?? json['answer'] ?? json['studentAnswer'])
              ?.toString(),
      acceptedText: accepted,
      isCorrect: json['isCorrect'] as bool?,
    );
  }
}

/// One graded Column A row of a `match_the_column` result.
///
/// [studentRightText] is null **only** when the row was left blank — a
/// wrong answer still carries the text the student picked (including a
/// distractor, which was a real option on their screen). Render null as
/// "Not answered", never as a wrong answer.
class ExamResultMatchRow {
  /// 1-based Column A row number.
  final int index;
  final String leftText;
  final String? correctRightText;
  final String? studentRightText;
  final bool isCorrect;

  const ExamResultMatchRow({
    required this.index,
    required this.leftText,
    this.correctRightText,
    this.studentRightText,
    this.isCorrect = false,
  });

  bool get isUnanswered => (studentRightText ?? '').trim().isEmpty;

  factory ExamResultMatchRow.fromJson(Map<String, dynamic> json) {
    return ExamResultMatchRow(
      index: _asInt(json['index']) ?? 0,
      leftText: (json['leftText'] ?? '').toString(),
      correctRightText: json['correctRightText']?.toString(),
      studentRightText: json['studentRightText']?.toString(),
      isCorrect: json['isCorrect'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Attempt history
// ─────────────────────────────────────────────────────────────────────────

class AttemptHistoryItem {
  final int attemptId;
  final int attemptNo;
  final String status; // e.g. evaluated
  final double? score;
  final double? maxScore;
  final double? percentage;
  final bool? isPassed;
  final bool hasPassMark;
  final bool isAutoSubmitted;
  final DateTime? submittedAt;
  final bool isCurrent;

  const AttemptHistoryItem({
    required this.attemptId,
    required this.attemptNo,
    required this.status,
    this.score,
    this.maxScore,
    this.percentage,
    this.isPassed,
    this.hasPassMark = false,
    this.isAutoSubmitted = false,
    this.submittedAt,
    this.isCurrent = false,
  });

  bool get isEvaluated => status.trim().toLowerCase() == 'evaluated';

  factory AttemptHistoryItem.fromJson(Map<String, dynamic> json) {
    return AttemptHistoryItem(
      attemptId: _asInt(json['attemptId']) ?? 0,
      attemptNo: _asInt(json['attemptNo']) ?? 0,
      status: (json['status'] ?? '').toString(),
      score: _asDouble(json['score']),
      maxScore: _asDouble(json['maxScore']),
      percentage: _asDouble(json['percentage']),
      isPassed: json['isPassed'] as bool?,
      hasPassMark: json['hasPassMark'] == true,
      isAutoSubmitted: json['isAutoSubmitted'] == true,
      submittedAt: parseExamUtc(json['submittedAt']),
      isCurrent: json['isCurrent'] == true,
    );
  }
}
