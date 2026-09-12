import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/entities/exam_context.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class ReattemptExamUseCase {
  final ExamRepository repository;

  ReattemptExamUseCase(this.repository);

  Future<Either<Failure, AttemptStateResponse>> call({
    required int examId,
    required String phoneNumber,
    ExamContext context = ExamContext.standalone,
  }) {
    return repository.reattempt(
      examId: examId,
      phoneNumber: phoneNumber,
      context: context,
    );
  }
}
