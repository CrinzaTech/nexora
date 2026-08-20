import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/assignment/data/models/assignment_model.dart';

abstract class AssignmentRepository {
  /// Fetches the assignment by [assignmentId] (the int carried in the
  /// curriculum node's `url` field). Implementation tolerates both
  /// single-object and list responses (see [Assignment.resolve]).
  ///
  /// [nodeId] is the curriculum tree node id — the backend's GET response
  /// doesn't echo it back, so the repo injects it into the resulting
  /// [Assignment] so a follow-up submit can carry a real `JsonNodeId`.
  Future<Either<Failure, Assignment>> getAssignment({
    required int assignmentId,
    required String nodeId,
  });

  /// Submit (or resubmit) the assignment. [submissionId] of `0` signals
  /// "create new"; non-zero updates the existing submission.
  Future<Either<Failure, Assignment>> submitAssignment({
    required int courseId,
    required int assignmentId,
    required String jsonNodeId,
    required int submissionId,
    required File file,
  });
}
