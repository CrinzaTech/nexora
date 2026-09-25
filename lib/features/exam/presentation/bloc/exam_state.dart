part of 'exam_cubit.dart';

@freezed
sealed class ExamState with _$ExamState {
  const factory ExamState.initial() = _Initial;

  /// Busy — resolving phone, hitting the gate, fetching a paper/result, etc.
  const factory ExamState.loading() = _Loading;

  /// Intro / gate screen: shows instructions, duration, attempts, and the
  /// right CTA (Start / Resume / Reattempt / view last result / closed).
  const factory ExamState.gate(AttemptStateResponse gate) = _Gate;

  /// Exam mode this app doesn't support yet (competitive) or another
  /// unsupported situation. [reason] is shown to the student.
  const factory ExamState.notSupported(String reason) = _NotSupported;

  /// Actively taking a normal-mode paper. [answers] is a fresh map each
  /// emit so state equality triggers a rebuild. [autosaveStopped] flips
  /// once the deadline+grace has passed (client stops autosaving).
  ///
  /// [pinnedQuestionIds] holds top-level question ids the student parked to
  /// revisit. Client-only — never sent to the server, and normal mode only.
  const factory ExamState.taking({
    required ExamPaperResponse paper,
    required Map<int, ExamAnswerDraft> answers,
    DateTime? deadlineUtc,
    @Default(false) bool autosaveStopped,
    @Default(<int>{}) Set<int> pinnedQuestionIds,
  }) = _Taking;

  /// Competitive mode: a single current question. [draft] is the
  /// in-progress answer for this question; [submitting] is true while the
  /// answer is being recorded / advancing.
  const factory ExamState.competitiveQuestion({
    required CompetitiveQuestionResponse data,
    required ExamAnswerDraft draft,
    DateTime? deadlineUtc,
    @Default(false) bool submitting,
  }) = _CompetitiveQuestion;

  /// Quiz mode: a single current question with instant feedback.
  ///
  /// Quiz mode is paged one question at a time whatever [examMode] says,
  /// so it shares the competitive question payload — only the answering
  /// endpoint and this feedback loop differ.
  ///
  /// [feedback] is null while the student is still choosing; once set, the
  /// answer has been graded and the view is showing right/wrong. From
  /// there the student either retries (feedback cleared, a fresh pick),
  /// waves the question through, or moves on.
  ///
  /// [wrongOptionIds] remembers which options were already tried and found
  /// wrong on THIS question, so a retry doesn't quietly spend budget on a
  /// pick the student has already been told is wrong.
  const factory ExamState.quizQuestion({
    required CompetitiveQuestionResponse data,
    required ExamAnswerDraft draft,
    QuizAnswerResultResponse? feedback,
    DateTime? deadlineUtc,
    @Default(false) bool submitting,
    @Default(0) int retryPointsUsed,
    @Default(0) int retryPoints,
    @Default(<int>{}) Set<int> wrongOptionIds,

    /// 1-based numbers of the questions the student pinned. Kept by number
    /// rather than id because the progress grid spans questions the server
    /// has not served yet, whose ids the client has never seen.
    @Default(<int>{}) Set<int> pinnedQuestionNumbers,

    /// 1-based numbers of the questions this client has served and seen
    /// settle, so it can show them again. Not simply "everything before
    /// the current one": a student resuming mid-attempt never saw the
    /// earlier questions, and those cells must not offer a review that
    /// would come back empty.
    @Default(<int>{}) Set<int> reviewableQuestionNumbers,
  }) = _QuizQuestion;

  /// Practice drill: one question from a locally held paper. Nothing is
  /// recorded server-side, so there is no attempt, timer or submit.
  ///
  /// [verdict] is null while the student is choosing; once set, the pick
  /// has been checked and the right answer is on screen. [error] is a
  /// one-off message (a failed check) shown without leaving the question.
  const factory ExamState.practiceQuestion({
    required String examTitle,
    required PracticeItem item,
    required int number,
    required int total,
    required ExamAnswerDraft draft,
    PracticeAnswerResultResponse? verdict,
    @Default(false) bool checking,
    String? error,
    @Default(false) bool allowCalculator,
    @Default(ExamCalculatorType.simple) ExamCalculatorType calculatorType,

    /// 0-based index → whether that question was checked correct. Only
    /// checked questions appear; drives the review grid.
    @Default(<int, bool>{}) Map<int, bool> outcomes,

    /// 0-based indexes the student has been on. Visited but unchecked
    /// reads as skipped; never visited reads as not seen.
    @Default(<int>{}) Set<int> visited,
  }) = _PracticeQuestion;

  /// Practice drill finished: the client's own tally — nothing is banked.
  const factory ExamState.practiceSummary({
    required String examTitle,
    required int correct,
    required int answered,
    required int total,
  }) = _PracticeSummary;

  /// Competitive mode: the between-sections transition screen shown after
  /// the last question of a section is answered.
  const factory ExamState.sectionTransition({
    String? fromSectionName,
    required String nextSectionName,
    DateTime? deadlineUtc,
    @Default(false) bool loading,
  }) = _SectionTransition;

  /// Grading in progress after Submit.
  const factory ExamState.submitting() = _Submitting;

  /// Graded result (or the "results held" screen when not visible).
  ///
  /// [pinnedQuestionIds] carries the pins the student set while sitting
  /// THIS attempt, so the questions they flagged to come back to are still
  /// marked when they finally get to review them. Empty when reopening a
  /// different attempt from history — those pins were never made here.
  const factory ExamState.result(
    ExamResultResponse result, {
    @Default(<int>{}) Set<int> pinnedQuestionIds,
  }) = _Result;

  const factory ExamState.error(String message) = _Error;
}

/// Budget arithmetic for the quiz state, kept off the generated class.
extension _QuizQuestionPoints on _QuizQuestion {
  /// Points still to spend on this attempt, floored at zero.
  int get pointsRemaining =>
      (retryPoints - retryPointsUsed).clamp(0, retryPoints);

  /// Whether a reveal is affordable. The server refuses one below the
  /// price, so the UI disables it rather than firing a doomed call.
  bool get canAffordReveal => pointsRemaining >= QuizPointCosts.reveal;
}
