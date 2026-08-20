import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_detail_usecase.dart';

part 'pricing_tiers_state.dart';
part 'pricing_tiers_cubit.freezed.dart';

/// Loads the buyable tiers for a course (the `pricing.pricing[]` array
/// on the course-detail v2 response).
///
/// Sits in front of the existing [CoursePricingCubit] in the buy flow:
/// the user taps Buy / Choose Plan, this cubit resolves the tier list,
/// the widget then either auto-proceeds (single tier) or opens the
/// Choose Plan sheet for the user to pick (multi-tier). Once a
/// `coursePricingId` is known, [CoursePricingCubit.load] takes over
/// to fetch the per-tier price breakdown for the enrolment sheet.
class PricingTiersCubit extends SafeCubit<PricingTiersState> {
  final GetCourseDetailUseCase getCourseDetailUseCase;

  PricingTiersCubit({required this.getCourseDetailUseCase})
      : super(const PricingTiersState.initial());

  Future<void> load(int courseId) async {
    emit(const PricingTiersState.loading());
    final result = await getCourseDetailUseCase(courseId: courseId);
    result.fold(
      (failure) => emit(PricingTiersState.error(failure.message)),
      (course) => emit(PricingTiersState.loaded(course.pricing)),
    );
  }

  void reset() => emit(const PricingTiersState.initial());
}
