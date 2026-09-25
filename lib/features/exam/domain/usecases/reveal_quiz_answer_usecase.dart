import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

/// Quiz mode: spend [QuizPointCosts.reveal] points to be shown the answer
/// and its explanation.
///
/// The question then earns its **full marks**; the price is paid in rank,
/// not in score.
///
/// [questionId] names the question to reveal. Omit it for the one the
/// attempt is on, which is what the server assumes and how this call
/// behaved before look-back hints existed; the paper then advances. Pass
/// it to reveal a question already gone past, in which case the position
/// stays exactly where it is.
class RevealQuizAnswerUseCase {
  final ExamRepository repository;

  RevealQuizAnswerUseCase(this.repository);

  Future<Either<Failure, QuizAnswerResultResponse>> call({
    required int attemptId,
    required String phoneNumber,
    int? questionId,
  }) {
    return repository.revealAnswer(
      attemptId: attemptId,
      phoneNumber: phoneNumber,
      questionId: questionId,
    );
  }
}
