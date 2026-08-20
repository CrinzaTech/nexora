import 'dart:async';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_my_courses_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/rewatch_course_usecase.dart';

part 'my_courses_state.dart';
part 'my_courses_cubit.freezed.dart';

/// Drives the My Courses tab. Backed by `GET /api/v1/course/my-courses`,
/// which returns every purchased course (irrespective of progress) so the
/// page can split them into the In Progress / Completed tabs locally.
class MyCoursesCubit extends SafeCubit<MyCoursesState> {
  final GetMyCoursesUseCase getMyCoursesUseCase;
  final RewatchCourseUseCase rewatchCourseUseCase;

  MyCoursesCubit({
    required this.getMyCoursesUseCase,
    required this.rewatchCourseUseCase,
  }) : super(const MyCoursesState.initial());

  Future<void> load() async {
    emit(const MyCoursesState.loading());
    final result = await getMyCoursesUseCase();
    result.fold(
      (failure) => emit(MyCoursesState.error(failure.message)),
      (courses) => emit(MyCoursesState.loaded(courses)),
    );
  }

  /// Refetch without flashing `loading` — used by the page's pull-to-
  /// refresh so the existing list stays on screen and just updates in
  /// place. Errors are swallowed so a transient blip can't blank the
  /// list out from under the user.
  Future<void> silentRefresh() async {
    final result = await getMyCoursesUseCase();
    result.fold(
      (_) {},
      (courses) => emit(MyCoursesState.loaded(courses)),
    );
  }

  /// Resets a completed course's progress on the server, then patches
  /// the local list so the course slides from Completed → In Progress
  /// without a full refetch (keeps scroll position + avoids a flash).
  ///
  /// Returns `true` on success so the UI can react (snackbar, focus
  /// switch to the In Progress tab, etc.). Errors are emitted as
  /// `MyCoursesState.error` and the previously loaded list is restored.
  Future<bool> rewatch(int purchasedId) async {
    final current = state.maybeWhen(
      loaded: (c) => c,
      orElse: () => <CourseSummary>[],
    );
    final result = await rewatchCourseUseCase(purchasedId: purchasedId);
    return result.fold(
      (failure) {
        // Surface the error transiently, then snap back to the loaded
        // list so the user can retry without losing context.
        emit(MyCoursesState.error(failure.message));
        emit(MyCoursesState.loaded(current));
        return false;
      },
      (_) {
        // Progress is now 0 server-side, so the completion tracker must
        // forget this course's nodes — otherwise its session cache still
        // reports them as marked and re-watching posts nothing, leaving
        // progress stuck at 0 until the next app launch.
        unawaited(sl<ContentCompletionService>().forgetCourse(purchasedId));
        final updated = [
          for (final c in current)
            c.purchasedId == purchasedId
                ? c.copyWith(courseCompletionPercentage: 0)
                : c,
        ];
        emit(MyCoursesState.loaded(updated));
        return true;
      },
    );
  }

  void reset() => emit(const MyCoursesState.initial());
}
