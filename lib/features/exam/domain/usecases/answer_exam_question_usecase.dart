import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class AnswerExamQuestionUseCase {
  final ExamRepository repository;

  AnswerExamQuestionUseCase(this.repository);

  Future<Either<Failure, CompetitiveAnswerResultResponse>> call({
    required int attemptId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
  }) {
    return repository.answerQuestion(
      attemptId: attemptId,
      phoneNumber: phoneNumber,
      answer: answer,
    );
  }
}
