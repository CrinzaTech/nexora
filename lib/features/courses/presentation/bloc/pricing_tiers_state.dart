part of 'pricing_tiers_cubit.dart';

@freezed
class PricingTiersState with _$PricingTiersState {
  const factory PricingTiersState.initial() = _Initial;
  const factory PricingTiersState.loading() = _Loading;

  /// The full tier list pulled off `course.pricing`. The list can be
  /// empty (free course / unconfigured) — the buy widget surfaces a
  /// "pricing unavailable" snackbar in that case rather than emitting
  /// a separate state for it.
  const factory PricingTiersState.loaded(List<CoursePricingTier> tiers) =
      _Loaded;
  const factory PricingTiersState.error(String message) = _Error;
}
