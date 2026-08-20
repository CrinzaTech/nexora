import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class SubmitExamUseCase {
  final ExamRepository repository;

  SubmitExamUseCase(this.repository);

  Future<Either<Failure, ExamResultResponse>> call({
    required int attemptId,
    required String phoneNumber,
    required bool autoSubmitted,
    required List<Map<String, dynamic>> answers,
  }) {
    return repository.submit(
      attemptId: attemptId,
      phoneNumber: phoneNumber,
      autoSubmitted: autoSubmitted,
      answers: answers,
    );
  }
}
