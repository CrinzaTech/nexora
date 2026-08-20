import 'dart:io';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/assignment/data/models/assignment_model.dart';
import 'package:nexora/features/assignment/domain/usecases/get_assignment_usecase.dart';
import 'package:nexora/features/assignment/domain/usecases/submit_assignment_usecase.dart';

part 'assignment_state.dart';
part 'assignment_cubit.freezed.dart';

class AssignmentCubit extends SafeCubit<AssignmentState> {
  final GetAssignmentUseCase getAssignmentUseCase;
  final SubmitAssignmentUseCase submitAssignmentUseCase;

  AssignmentCubit({
    required this.getAssignmentUseCase,
    required this.submitAssignmentUseCase,
  }) : super(const AssignmentState.initial());

  Future<void> load({
    required int assignmentId,
    required String nodeId,
  }) async {
    emit(const AssignmentState.loading());
    await _fetch(assignmentId, nodeId);
  }

  /// Refetches without bouncing through `loading` — used post-submit so
  /// the UI doesn't flash a spinner over a screen that already has
  /// content rendered.
  Future<void> _silentRefresh(int assignmentId, String nodeId) async {
    await _fetch(assignmentId, nodeId);
  }

  Future<void> _fetch(int assignmentId, String nodeId) async {
    final result = await getAssignmentUseCase(
      assignmentId: assignmentId,
      nodeId: nodeId,
    );
    result.fold(
      (failure) => emit(AssignmentState.error(failure.message)),
      (assignment) => emit(AssignmentState.loaded(assignment)),
    );
  }

  /// Submit the assignment with the picked [file]. The submit POST
  /// always carries the canonical `submissionId` from the currently
  /// loaded [Assignment]:
  ///
  ///   * `0` when the user has never submitted → backend creates a
  ///     fresh submission row.
  ///   * the real submission id otherwise → backend updates that row.
  ///
  /// After a successful submit we silently refetch the assignment so
  /// the next submit (or the rendered "Your Submission" card) carries
  /// the freshly-stamped submission id from the backend rather than
  /// any client-side guess.
  Future<void> submit({
    required int courseId,
    required String nodeId,
    required Assignment current,
    required File file,
  }) async {
    // jsonNodeId is required on the multipart body — guard at the cubit
    // edge so a misconfigured caller fails loudly here instead of the
    // backend rejecting a request with an empty JsonNodeId.
    assert(nodeId.isNotEmpty, 'nodeId is required to submit an assignment');
    emit(AssignmentState.submitting(current));
    final result = await submitAssignmentUseCase(
      courseId: courseId,
      assignmentId: current.assignmentId,
      jsonNodeId: nodeId,
      // 0 == "create new"; non-zero == "update existing". This is the
      // contract the backend documents on /api/v1/course/assignment.
      submissionId: current.submissionId,
      file: file,
    );
    await result.fold(
      (failure) async {
        // Drop back to `loaded` so the user can retry. Surface the
        // error via a separate `error` state for the listener (and
        // keep `loaded` afterward so the UI stays populated).
        emit(AssignmentState.error(failure.message));
        emit(AssignmentState.loaded(current));
      },
      (updated) async {
        // Merge whatever fields the submit response echoed back over
        // the previously-loaded Assignment so the UI snaps to a
        // "submitted" state immediately. The merge never invents a
        // submission id — that would corrupt the next submit (the
        // backend would treat a fake id as "update existing"). When
        // the backend doesn't echo an id, we keep the original
        // (still 0 for a brand-new submit) and rely on the silent
        // refetch below to canonicalise from the live GET response.
        final merged = current.copyWith(
          assignmentId: updated.assignmentId == 0
              ? current.assignmentId
              : updated.assignmentId,
          submissionId: updated.submissionId != 0
              ? updated.submissionId
              : current.submissionId,
          submissionFileUrl:
              updated.submissionFileUrl ?? current.submissionFileUrl,
          submittedAt: updated.submittedAt ?? DateTime.now(),
          grade: updated.grade ?? current.grade,
          feedback: updated.feedback ?? current.feedback,
        );
        emit(AssignmentState.submitted(merged));
        // Canonicalise: re-fetch so a follow-up resubmit carries the
        // real submission id minted by the backend, not the
        // merge-shaped one we just emitted. Silent so the page
        // doesn't flash a loading spinner.
        await _silentRefresh(current.assignmentId, nodeId);
      },
    );
  }

  void reset() => emit(const AssignmentState.initial());
}
