import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';

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
  });

  /// Idempotent create-or-resume. Starts the clock the first time.
  Future<Either<Failure, AttemptStateResponse>> start({
    required int examId,
    required String phoneNumber,
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
  });

  /// Start a fresh attempt after a finished one.
  Future<Either<Failure, AttemptStateResponse>> reattempt({
    required int examId,
    required String phoneNumber,
  });
}
