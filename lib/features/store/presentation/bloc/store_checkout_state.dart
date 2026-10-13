part of 'store_checkout_cubit.dart';

@freezed
abstract class StoreCheckoutState with _$StoreCheckoutState {
  const StoreCheckoutState._();

  const factory StoreCheckoutState({
    required StoreCheckoutSource source,
    @Default(<StoreAddress>[]) List<StoreAddress> addresses,
    StoreAddress? address,
    @Default(false) bool loadingAddresses,
    String? addressesError,
    @Default(false) bool quoting,
    StoreQuote? quote,
    String? quoteError,

    /// P2 in flight.
    @Default(false) bool placing,

    /// This visit's order, once P2 answered. Reused for every retry.
    StorePlacedOrder? order,

    /// P3 in flight.
    @Default(false) bool verifying,

    /// Paid, being confirmed, or being refunded — nothing left to pay.
    @Default(false) bool finished,

    /// The latest one-shot for the page; [eventSeq] changes with each.
    StoreCheckoutEvent? event,
    @Default(0) int eventSeq,
  }) = _StoreCheckoutState;

  bool get busy => placing || verifying;

  /// Pay is live only on a quote that says so, with no request running.
  bool get canPay =>
      !finished &&
      !busy &&
      !quoting &&
      address != null &&
      (order != null || (quote?.canPlaceOrder ?? false));

  /// P2's amount once an order exists (it is re-priced there), the
  /// quote's until then. Never computed here.
  double? get payable => order?.amountRupees ?? quote?.payable;
}

/// One-shot instructions from the cubit to the checkout page.
@freezed
sealed class StoreCheckoutEvent with _$StoreCheckoutEvent {
  /// Open Razorpay with this order.
  const factory StoreCheckoutEvent.openPayment(StorePlacedOrder order) =
      StoreCheckoutOpenPayment;

  /// Order placed.
  const factory StoreCheckoutEvent.paid(String orderNo) = StoreCheckoutPaid;

  /// Razorpay has not captured it yet. **Do not offer to pay again.**
  const factory StoreCheckoutEvent.pending(String message, String orderNo) =
      StoreCheckoutPending;

  /// The order expired before the money arrived; refund is automatic.
  const factory StoreCheckoutEvent.refunding(String message, String orderNo) =
      StoreCheckoutRefunding;

  /// Payment did not go through. Pay again reuses the same order.
  const factory StoreCheckoutEvent.failed(String message) = StoreCheckoutFailed;

  /// P2 said no for good (sold out, …). The quote is being refreshed.
  const factory StoreCheckoutEvent.refused(String message) =
      StoreCheckoutRefused;

  /// P2 could not be confirmed either way. Pay again is safe — same key.
  const factory StoreCheckoutEvent.error(String message) = StoreCheckoutError;
}
