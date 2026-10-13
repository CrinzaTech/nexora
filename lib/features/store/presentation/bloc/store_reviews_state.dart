part of 'store_reviews_cubit.dart';

@freezed
abstract class StoreReviewsState with _$StoreReviewsState {
  const factory StoreReviewsState({
    @Default(<StoreReview>[]) List<StoreReview> items,
    @Default(0) int pageNo,
    @Default(0) int total,
    @Default(false) bool hasMore,
    @Default(false) bool loading,
    @Default(false) bool loadingMore,
    String? error,
  }) = _StoreReviewsState;
}
