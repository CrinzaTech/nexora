part of 'bundle_checkout_cubit.dart';

@freezed
sealed class BundleCheckoutState with _$BundleCheckoutState {
  /// Nothing in flight. Also where a dismissed sheet lands.
  const factory BundleCheckoutState.idle() = _Idle;

  /// P1 in flight.
  const factory BundleCheckoutState.creatingOrder() = _CreatingOrder;

  /// P1 priced it differently from what the page showed. The page shows
  /// [order]'s breakdown and opens Razorpay only on confirmation.
  const factory BundleCheckoutState.priceChanged(BundleOrder order) =
      _PriceChanged;

  /// Order ready. The page opens the Razorpay sheet on this.
  const factory BundleCheckoutState.orderReady(BundleOrder order) = _OrderReady;

  /// P2 in flight — money has moved, nothing is unlocked yet.
  const factory BundleCheckoutState.verifying() = _Verifying;

  /// Unlocked. Every course is in My Courses now.
  const factory BundleCheckoutState.paid(String message) = _Paid;

  /// Captured but not confirmed; polling B2. **Never offer to pay again.**
  const factory BundleCheckoutState.confirming(String message) = _Confirming;

  /// A minute of polling and still not confirmed. The webhook will get
  /// there; the learner is told so, and still not offered a retry.
  const factory BundleCheckoutState.stillPending(String message) =
      _StillPending;

  /// P1 declined to sell (off sale, owns every course, not found). No
  /// sheet opened and nothing was charged; retrying cannot help.
  const factory BundleCheckoutState.refused(String message) = _Refused;

  /// Nothing was unlocked. [canRetry] is false where a second attempt
  /// could only produce a second charge to refund, or cannot succeed.
  const factory BundleCheckoutState.failed(String message, bool canRetry) =
      _Failed;
}
