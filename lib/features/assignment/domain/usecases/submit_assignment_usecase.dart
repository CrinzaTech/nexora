import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/assignment/data/models/assignment_model.dart';
import 'package:nexora/features/assignment/domain/repositories/assignment_repository.dart';

class SubmitAssignmentUseCase {
  final AssignmentRepository repository;

  SubmitAssignmentUseCase(this.repository);

  Future<Either<Failure, Assignment>> call({
    required int courseId,
    required int assignmentId,
    required String jsonNodeId,
    required int submissionId,
    required File file,
  }) {
    return repository.submitAssignment(
      courseId: courseId,
      assignmentId: assignmentId,
      jsonNodeId: jsonNodeId,
      submissionId: submissionId,
      file: file,
    );
  }
}
