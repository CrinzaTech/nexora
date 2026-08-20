part of 'webinar_checkout_cubit.dart';

@freezed
class WebinarCheckoutState with _$WebinarCheckoutState {
  /// Nothing in flight. Also where a dismissed sheet lands — closing
  /// Razorpay charges nothing, so it is not a failure.
  const factory WebinarCheckoutState.idle() = _Idle;

  /// P1 in flight.
  const factory WebinarCheckoutState.creatingOrder() = _CreatingOrder;

  /// Order priced. The page opens the Razorpay sheet on this.
  const factory WebinarCheckoutState.orderReady(WebinarOrder order) =
      _OrderReady;

  /// P2 in flight — the money has moved but the seat does not exist yet.
  const factory WebinarCheckoutState.verifying() = _Verifying;

  /// `paid: true`. [session] is the lobby payload P2 returned, so the
  /// caller can route straight on to the room; null when the seat came
  /// from somewhere other than a payment (a webinar that turned out to
  /// be free).
  const factory WebinarCheckoutState.paid(WebinarSessionState? session) =
      _Paid;

  /// They already own it — P1 refuses a second purchase. Straight in.
  const factory WebinarCheckoutState.alreadyPaid(String message) =
      _AlreadyPaid;

  /// Nothing was charged, or the payment was not captured. [canRetry] is
  /// false for a signature mismatch: retrying a payment we could not
  /// verify only produces a second one to refund.
  const factory WebinarCheckoutState.failed(String message, bool canRetry) =
      _Failed;

  /// **We could not reach Razorpay to confirm.** Money may well have
  /// left the account. This is deliberately not [failed]: the only safe
  /// thing to offer here is "refresh", never "pay again".
  const factory WebinarCheckoutState.unresolved(String message) = _Unresolved;
}
