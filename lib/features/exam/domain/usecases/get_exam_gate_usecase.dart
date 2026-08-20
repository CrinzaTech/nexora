import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class GetExamGateUseCase {
  final ExamRepository repository;

  GetExamGateUseCase(this.repository);

  Future<Either<Failure, AttemptStateResponse>> call({
    required int examId,
    required String phoneNumber,
  }) {
    return repository.getGate(examId: examId, phoneNumber: phoneNumber);
  }
}
