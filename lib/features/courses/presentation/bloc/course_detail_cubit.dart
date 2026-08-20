import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_detail_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/save_continue_course_usecase.dart';

part 'course_detail_state.dart';
part 'course_detail_cubit.freezed.dart';

class CourseDetailCubit extends SafeCubit<CourseDetailState> {
  final GetCourseDetailUseCase getCourseDetailUseCase;
  final SaveContinueCourseUseCase saveContinueCourseUseCase;

  /// Tracked so [enroll] knows which course to mark without callers having
  /// to thread `courseId` through twice.
  int? _lastLoadedCourseId;

  /// Mutex against double-taps on the Enroll button — keeps the bottom bar
  /// visually steady while the POST + silent refetch is in flight.
  bool _isEnrolling = false;

  CourseDetailCubit({
    required this.getCourseDetailUseCase,
    required this.saveContinueCourseUseCase,
  }) : super(const CourseDetailState.initial());

  Future<void> load(int courseId) async {
    _lastLoadedCourseId = courseId;
    emit(const CourseDetailState.loading());
    final result = await getCourseDetailUseCase(courseId: courseId);
    result.fold((failure) => emit(CourseDetailState.error(failure.message)), (
      course,
    ) {
      emit(CourseDetailState.loaded(course));
      // Fire-and-forget: register the course as viewed. Mirror the
      // backend's `isPurchased` so we don't accidentally downgrade an
      // already-purchased course back to "browsing" on every open.
      // Errors are intentionally swallowed — this must never block or
      // crash the detail UI.
      saveContinueCourseUseCase(
        courseId: courseId,
        isPurchased: course.isPurchased,
      ).ignore();
    });
  }

  /// Marks the currently-loaded course as enrolled (`isPurchased: true`)
  /// then silently re-fetches the detail so the loaded payload reflects the
  /// change. We deliberately do NOT pass through `loading` during the
  /// re-fetch so the bottom bar / body stay on screen — the only visible
  /// effect is the CTA flipping from "Enroll Now" to "Continue Learning".
  Future<void> enroll() async {
    if (_isEnrolling) return;
    final courseId = _lastLoadedCourseId;
    if (courseId == null) return;
    _isEnrolling = true;
    try {
      final saveResult = await saveContinueCourseUseCase(
        courseId: courseId,
        isPurchased: true,
      );
      await saveResult.fold(
        (failure) async => emit(CourseDetailState.error(failure.message)),
        (_) async {
          final freshResult = await getCourseDetailUseCase(courseId: courseId);
          freshResult.fold(
            (failure) => emit(CourseDetailState.error(failure.message)),
            (course) => emit(CourseDetailState.loaded(course)),
          );
        },
      );
    } finally {
      _isEnrolling = false;
    }
  }

  void reset() => emit(const CourseDetailState.initial());
}
