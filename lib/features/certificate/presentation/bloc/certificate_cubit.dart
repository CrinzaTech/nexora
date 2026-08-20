import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/domain/usecases/get_completed_courses_usecase.dart';

part 'certificate_state.dart';
part 'certificate_cubit.freezed.dart';

/// Drives the Course Certificates screen. Owns the completed-course list
/// only — the per-row download keeps its spinner locally (see
/// [CertificateCourseTile]) so one row can be busy without rebuilding,
/// or disabling, the whole list.
class CertificateCubit extends SafeCubit<CertificateState> {
  final GetCompletedCoursesUseCase getCompletedCoursesUseCase;

  CertificateCubit({required this.getCompletedCoursesUseCase})
    : super(const CertificateState.initial());

  Future<void> load() => _fetch(showLoading: true);

  /// Refetch without flashing `loading` — pull-to-refresh keeps the
  /// current list on screen. A downloaded certificate flips `isIssued`
  /// and fills in `certificateNo`, so this is also how the list picks
  /// those up after the learner comes back from the preview.
  Future<void> silentRefresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const CertificateState.loading());
    final result = await getCompletedCoursesUseCase();
    result.fold((failure) {
      // A silent refresh that fails leaves the existing list alone —
      // a transient blip shouldn't blank the screen.
      if (showLoading) emit(CertificateState.error(failure.message));
    }, (courses) => emit(CertificateState.loaded(courses)));
  }

  void reset() => emit(const CertificateState.initial());
}
