import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/entities/exam_context.dart';

/// Contract for the student exam-taking flow (`api/v1/exam`, normal mode).
///
/// Every call requires the authenticated student's `phoneNumber` — resolve
/// it once via [resolvePhoneNumber] and thread it through.
abstract class ExamRepository {
  /// The signed-in student's phone number (needed on every exam call). The
  /// server cross-checks it against the JWT's own account.
  Future<Either<Failure, String>> resolvePhoneNumber();

  /// Read-only gate check. Never creates an attempt.
  Future<Either<Failure, AttemptStateResponse>> getGate({
    required int examId,
    required String phoneNumber,
    ExamContext context,
  });

  /// Idempotent create-or-resume. Starts the clock the first time.
  Future<Either<Failure, AttemptStateResponse>> start({
    required int examId,
    required String phoneNumber,
    ExamContext context,
  });

  /// Whole paper for a normal-mode attempt, with saved answers repainted.
  Future<Either<Failure, ExamPaperResponse>> getPaper({
    required int attemptId,
    required String phoneNumber,
  });

  /// Competitive mode: the current question (stamps the server-side
  /// shown_at timer).
  Future<Either<Failure, CompetitiveQuestionResponse>> getQuestion({
    required int attemptId,
    required String phoneNumber,
  });

  /// Competitive mode: record the current question's answer and advance.
  /// [answer] is a single `StudentAnswerRequest` map.
  Future<Either<Failure, CompetitiveAnswerResultResponse>> answerQuestion({
    required int attemptId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
  });

  /// Quiz mode: grade the current question on the spot and report back
  /// whether it was right, plus what is left of the retry budget.
  ///
  /// [moveOn] is "I know it's wrong, keep it and go on" — it costs no
  /// retry, and without it a student out of ideas but not out of retries
  /// would be stuck, since quiz mode otherwise holds the paper until the
  /// answer is right or the budget is gone.
  ///
  /// [revise] re-answers a question the paper has already gone past:
  /// `answer.questionId` becomes the identity rather than a label, the
  /// server grades that question instead of the current one, and the
  /// position does not move. It costs the same point as any other
  /// re-submission and is refused on a revealed question.
  Future<Either<Failure, QuizAnswerResultResponse>> quizAnswerQuestion({
    required int attemptId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
    bool moveOn,
    bool revise,
  });

  /// Quiz mode: spend [QuizPointCosts.reveal] points to be shown the
  /// answer and its explanation.
  ///
  /// That question then earns its **full marks** — the points buy the
  /// mark, and what they cost is rank. Refused by the server below the
  /// price, so check affordability before offering it.
  ///
  /// [questionId] decides which question is revealed:
  ///
  ///  - **null** — the question the attempt is on. The paper then
  ///    **advances**; there is nothing left to answer once the answer has
  ///    been shown.
  ///  - **set** — that question instead, one the paper has already gone
  ///    past. Same price, same marks, but `advanced` comes back false and
  ///    `current_question_index` is untouched: the student is mid-question
  ///    somewhere else and must not be dragged backwards.
  Future<Either<Failure, QuizAnswerResultResponse>> revealAnswer({
    required int attemptId,
    required String phoneNumber,
    int? questionId,
  });

  /// Ungraded bulk autosave.
  Future<Either<Failure, SaveProgressResponse>> saveProgress({
    required int attemptId,
    required String phoneNumber,
    required List<Map<String, dynamic>> answers,
  });

  /// Final grading. Returns the (possibly gated) result.
  Future<Either<Failure, ExamResultResponse>> submit({
    required int attemptId,
    required String phoneNumber,
    required bool autoSubmitted,
    required List<Map<String, dynamic>> answers,
  });

  /// Reopen one of the student's own submitted attempts.
  Future<Either<Failure, ExamResultResponse>> getResult({
    required int attemptId,
    required String phoneNumber,
  });

  /// All of the student's attempts on this exam, newest first.
  Future<Either<Failure, List<AttemptHistoryItem>>> getHistory({
    required int examId,
    required String phoneNumber,
    ExamContext context,
  });

  /// Start a fresh attempt after a finished one.
  Future<Either<Failure, AttemptStateResponse>> reattempt({
    required int examId,
    required String phoneNumber,
    ExamContext context,
  });

  /// Top students at this placement, plus the caller's own standing.
  ///
  /// [top] is a rank cut-off, not a row count — ties at the cut-off are all
  /// returned, so the board can come back longer than asked for.
  Future<Either<Failure, ExamLeaderboard>> getLeaderboard({
    required int examId,
    required String phoneNumber,
    ExamContext context,
    int top,
  });

  /// Practice drill: the whole paper, freshly shuffled on every call.
  /// Keyed by exam, not attempt — a drill has no attempt (`attemptId` is 0,
  /// never send it anywhere) and no deadline.
  Future<Either<Failure, ExamPaperResponse>> getPracticePaper({
    required int examId,
    required String phoneNumber,
  });

  /// Practice drill: grade one answer. Stateless — nothing is written, and
  /// the right answer comes back whether this one was right or wrong.
  /// [answer] is a single `StudentAnswerRequest` map.
  Future<Either<Failure, PracticeAnswerResultResponse>> practiceAnswer({
    required int examId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
  });
}
