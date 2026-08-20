part of 'exam_cubit.dart';

@freezed
class ExamState with _$ExamState {
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
  const factory ExamState.taking({
    required ExamPaperResponse paper,
    required Map<int, ExamAnswerDraft> answers,
    DateTime? deadlineUtc,
    @Default(false) bool autosaveStopped,
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
  const factory ExamState.result(ExamResultResponse result) = _Result;

  const factory ExamState.error(String message) = _Error;
}
