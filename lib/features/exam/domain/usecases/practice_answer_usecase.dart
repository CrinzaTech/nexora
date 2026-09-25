import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

/// Practice drill: grade one answer. Stateless on the server — it returns
/// the right answer and explanation, and records nothing.
class PracticeAnswerUseCase {
  final ExamRepository repository;

  PracticeAnswerUseCase(this.repository);

  Future<Either<Failure, PracticeAnswerResultResponse>> call({
    required int examId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
  }) {
    return repository.practiceAnswer(
      examId: examId,
      phoneNumber: phoneNumber,
      answer: answer,
    );
  }
}
