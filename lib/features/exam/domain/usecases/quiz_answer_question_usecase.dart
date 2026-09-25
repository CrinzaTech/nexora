import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

/// Quiz mode: grade one question on the spot.
///
/// [moveOn] accepts a wrong answer and advances without spending a retry —
/// the way out for a student who has run out of ideas but not out of
/// budget, since quiz mode otherwise holds the paper on the question.
class QuizAnswerQuestionUseCase {
  final ExamRepository repository;

  QuizAnswerQuestionUseCase(this.repository);

  Future<Either<Failure, QuizAnswerResultResponse>> call({
    required int attemptId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
    bool moveOn = false,
    bool revise = false,
  }) {
    return repository.quizAnswerQuestion(
      attemptId: attemptId,
      phoneNumber: phoneNumber,
      answer: answer,
      moveOn: moveOn,
      revise: revise,
    );
  }
}
