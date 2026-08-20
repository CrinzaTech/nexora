part of 'course_pricing_cubit.dart';

@freezed
class CoursePricingState with _$CoursePricingState {
  const factory CoursePricingState.initial() = _Initial;
  const factory CoursePricingState.loading() = _Loading;
  const factory CoursePricingState.loaded(CoursePricing pricing) = _Loaded;
  const factory CoursePricingState.error(String message) = _Error;
}
