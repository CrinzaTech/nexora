import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class StartExamUseCase {
  final ExamRepository repository;

  StartExamUseCase(this.repository);

  Future<Either<Failure, AttemptStateResponse>> call({
    required int examId,
    required String phoneNumber,
  }) {
    return repository.start(examId: examId, phoneNumber: phoneNumber);
  }
}
