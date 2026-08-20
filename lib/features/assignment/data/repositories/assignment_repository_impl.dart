import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/assignment/data/models/assignment_model.dart';
import 'package:nexora/features/assignment/domain/repositories/assignment_repository.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  final ApiClient _apiClient;

  AssignmentRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, Assignment>> getAssignment({
    required int assignmentId,
    required String nodeId,
  }) async {
    try {
      final json = await _apiClient.getCourseAssignment(assignmentId);
      // Inject nodeId — the GET response doesn't include it, but every
      // downstream consumer (including the submit POST that requires a
      // non-empty JsonNodeId) reads it off the Assignment.
      final assignment = Assignment.resolve(json['data'], nodeId: nodeId);
      if (assignment == null) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Assignment not found',
          ),
        );
      }
      return Right(assignment);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Assignment>> submitAssignment({
    required int courseId,
    required int assignmentId,
    required String jsonNodeId,
    required int submissionId,
    required File file,
  }) async {
    try {
      final json = await _apiClient.submitCourseAssignment(
        courseId,
        assignmentId,
        jsonNodeId,
        submissionId,
        file,
      );
      // The submit response shape mirrors the GET — re-use the same
      // resolver. When the backend returns just `{success, message}`
      // we fall back to a thin Assignment that echoes whatever
      // submission id the caller passed in (0 stays 0, real id stays
      // the same). The cubit silently refetches the canonical
      // assignment afterward, so the real backend-stamped submission
      // id lands before the user can submit again. We deliberately
      // never invent a submission id here — sending a fake id on the
      // next submit would make the backend "update an existing
      // submission" that the user doesn't actually own.
      final resolved = Assignment.resolve(json['data'], nodeId: jsonNodeId);
      if (resolved != null) return Right(resolved);
      return Right(
        Assignment(
          assignmentId: assignmentId,
          courseId: courseId,
          jsonNodeId: jsonNodeId,
          title: '',
          description: '',
          submissionId: submissionId,
          submittedAt: DateTime.now(),
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
