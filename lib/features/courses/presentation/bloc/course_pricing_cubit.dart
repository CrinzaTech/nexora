import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_pricing_usecase.dart';

part 'course_pricing_state.dart';
part 'course_pricing_cubit.freezed.dart';

/// Drives the pricing breakdown shown on the enrolment bottom sheet.
///
/// Single flow: [load] fetches the v2 pricing breakdown for one
/// specific `(courseId, priceId)` pair. The tier-selection step that
/// produces `priceId` lives on `PricingTiersCubit`; this cubit no
/// longer auto-resolves a tier on its own — the buy widget always
/// hands it a concrete id (defaulted from `course.primaryPricing` or
/// chosen by the user via the Choose Plan sheet).
///
/// The v1 inline coupon-apply round trip is gone — coupon application
/// will land on a separate backend route the UI can wire up later.
class CoursePricingCubit extends SafeCubit<CoursePricingState> {
  final GetCoursePricingUseCase getCoursePricingUseCase;

  /// Holds the code currently affecting the [CoursePricing] state so it can
  /// be passed to the payment cubit when creating the order.
  String? appliedCouponCode;

  CoursePricingCubit({required this.getCoursePricingUseCase})
      : super(const CoursePricingState.initial());

  Future<void> load({required int courseId, required int priceId, String? couponCode}) async {
    emit(const CoursePricingState.loading());
    final result = await getCoursePricingUseCase(
      courseId: courseId,
      priceId: priceId,
      couponCode: couponCode,
    );
    result.fold(
      (failure) => emit(CoursePricingState.error(failure.message)),
      (pricing) {
        if (couponCode != null && pricing.isCouponApplied) {
          appliedCouponCode = couponCode;
        } else if (couponCode == null) {
          appliedCouponCode = null;
        }
        emit(CoursePricingState.loaded(pricing));
      },
    );
  }

  void reset() {
    appliedCouponCode = null;
    emit(const CoursePricingState.initial());
  }
}
