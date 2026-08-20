import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class GetExamHistoryUseCase {
  final ExamRepository repository;

  GetExamHistoryUseCase(this.repository);

  Future<Either<Failure, List<AttemptHistoryItem>>> call({
    required int examId,
    required String phoneNumber,
  }) {
    return repository.getHistory(examId: examId, phoneNumber: phoneNumber);
  }
}
