import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_categories_usecase.dart';

part 'course_filters_state.dart';
part 'course_filters_cubit.freezed.dart';

class CourseFiltersCubit extends SafeCubit<CourseFiltersState> {
  final GetCourseCategoriesUseCase getCourseCategoriesUseCase;

  CourseFiltersCubit({required this.getCourseCategoriesUseCase})
      : super(const CourseFiltersState.initial());

  Future<void> loadCategories() async {
    emit(const CourseFiltersState.loading());
    final result = await getCourseCategoriesUseCase();
    result.fold(
      (failure) => emit(CourseFiltersState.error(failure.message)),
      (data) => emit(CourseFiltersState.loaded(data)),
    );
  }
}
