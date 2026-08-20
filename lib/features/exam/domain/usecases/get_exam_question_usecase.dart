import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class GetExamQuestionUseCase {
  final ExamRepository repository;

  GetExamQuestionUseCase(this.repository);

  Future<Either<Failure, CompetitiveQuestionResponse>> call({
    required int attemptId,
    required String phoneNumber,
  }) {
    return repository.getQuestion(attemptId: attemptId, phoneNumber: phoneNumber);
  }
}
