import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class GetExamResultUseCase {
  final ExamRepository repository;

  GetExamResultUseCase(this.repository);

  Future<Either<Failure, ExamResultResponse>> call({
    required int attemptId,
    required String phoneNumber,
  }) {
    return repository.getResult(attemptId: attemptId, phoneNumber: phoneNumber);
  }
}
