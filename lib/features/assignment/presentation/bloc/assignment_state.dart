part of 'assignment_cubit.dart';

@freezed
class AssignmentState with _$AssignmentState {
  const factory AssignmentState.initial() = _Initial;
  const factory AssignmentState.loading() = _Loading;
  const factory AssignmentState.loaded(Assignment assignment) = _Loaded;
  const factory AssignmentState.submitting(Assignment assignment) = _Submitting;
  const factory AssignmentState.submitted(Assignment assignment) = _Submitted;
  const factory AssignmentState.error(String message) = _Error;
}
