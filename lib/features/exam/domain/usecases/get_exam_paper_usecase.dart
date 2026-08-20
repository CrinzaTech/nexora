import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class GetExamPaperUseCase {
  final ExamRepository repository;

  GetExamPaperUseCase(this.repository);

  Future<Either<Failure, ExamPaperResponse>> call({
    required int attemptId,
    required String phoneNumber,
  }) {
    return repository.getPaper(attemptId: attemptId, phoneNumber: phoneNumber);
  }
}
