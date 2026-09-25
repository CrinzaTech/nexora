import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

/// Practice drill: fetch the whole paper, reshuffled on every call.
class GetPracticePaperUseCase {
  final ExamRepository repository;

  GetPracticePaperUseCase(this.repository);

  Future<Either<Failure, ExamPaperResponse>> call({
    required int examId,
    required String phoneNumber,
  }) {
    return repository.getPracticePaper(
      examId: examId,
      phoneNumber: phoneNumber,
    );
  }
}
