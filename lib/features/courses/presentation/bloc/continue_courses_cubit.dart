import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_continue_courses_usecase.dart';

part 'continue_courses_state.dart';
part 'continue_courses_cubit.freezed.dart';

class ContinueCoursesCubit extends SafeCubit<ContinueCoursesState> {
  final GetContinueCoursesUseCase getContinueCoursesUseCase;

  ContinueCoursesCubit({required this.getContinueCoursesUseCase})
      : super(const ContinueCoursesState.initial());

  Future<void> load() async {
    emit(const ContinueCoursesState.loading());
    final result = await getContinueCoursesUseCase();
    result.fold(
      (failure) => emit(ContinueCoursesState.error(failure.message)),
      (courses) => emit(ContinueCoursesState.loaded(courses)),
    );
  }

  /// Refetch without flashing `loading` — used when the dashboard re-enters
  /// the Home tab so the Continue Learning rail stays on screen and just
  /// updates in place. Errors are swallowed so a transient failure can't
  /// blank out an existing list.
  Future<void> silentRefresh() async {
    final result = await getContinueCoursesUseCase();
    result.fold(
      (_) {},
      (courses) => emit(ContinueCoursesState.loaded(courses)),
    );
  }

  /// Drops the course with the given id from the in-memory list,
  /// emitting a fresh `loaded` state. Used right after a successful
  /// purchase from the Continue Your Purchase rail so the card
  /// disappears immediately — the next silent refresh / API roundtrip
  /// will confirm the change server-side.
  void removeCourse(int courseId) {
    state.maybeWhen(
      loaded: (courses) {
        final remaining = courses.where((c) => c.courseId != courseId).toList();
        emit(ContinueCoursesState.loaded(remaining));
      },
      orElse: () {},
    );
  }

  void reset() => emit(const ContinueCoursesState.initial());
}
