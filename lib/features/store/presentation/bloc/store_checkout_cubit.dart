import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/models/store_checkout_model.dart';
import 'package:nexora/features/store/domain/usecases/store_address_usecases.dart';
import 'package:nexora/features/store/domain/usecases/store_checkout_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_checkout_state.dart';
part 'store_checkout_cubit.freezed.dart';

/// Checkout: pick an address, quote (P1), place (P2), pay through
/// Razorpay, verify (P3).
///
/// The rules from STORE_API.md this exists to keep:
///
///  * **Quote before paying.** On open and on every address change; Pay
///    is enabled only while `canPlaceOrder`.
///  * **One idempotency key per checkout attempt.** Made on the first tap
///    of Pay and reused for any retry of P2 after a timeout — the same key
///    returns the same order and never charges twice.
///  * **One order per visit.** After a failed or cancelled payment,
///    Razorpay is reopened with the *same* P2 data; P2 is not called again
///    while the learner stays here, or stock would be held twice.
///  * **The order is placed by the server.** Only P3's `paid: true` (or
///    the webhook) makes it real; a Razorpay success callback is just the
///    cue to ask.
///
/// The Razorpay sheet itself belongs to the page (a plugin with listeners
/// and a disposal contract). This cubit tells it when to open through
/// [StoreCheckoutEvent.openPayment].
class StoreCheckoutCubit extends SafeCubit<StoreCheckoutState> {
  final GetStoreAddressesUseCase getAddressesUseCase;
  final GetStoreQuoteUseCase getQuoteUseCase;
  final PlaceStoreOrderUseCase placeOrderUseCase;
  final VerifyStorePaymentUseCase verifyPaymentUseCase;

  StoreCheckoutCubit({
    required StoreCheckoutSource source,
    required this.getAddressesUseCase,
    required this.getQuoteUseCase,
    required this.placeOrderUseCase,
    required this.verifyPaymentUseCase,
  }) : super(StoreCheckoutState(source: source));

  /// Lives for one checkout attempt. Null until Pay is first tapped.
  String? _idempotencyKey;

  /// Drops quote answers for an address the learner has since changed.
  int _quoteGeneration = 0;

  Future<void> start() async {
    emit(state.copyWith(loadingAddresses: true, addressesError: null));
    final result = await getAddressesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingAddresses: false,
          addressesError: storeErrorText(failure),
        ),
      ),
      (addresses) {
        final chosen =
            addresses.where((a) => a.isDefault).firstOrNull ??
            addresses.firstOrNull;
        emit(
          state.copyWith(
            loadingAddresses: false,
            addresses: addresses,
            address: chosen,
          ),
        );
        if (chosen != null) _quote();
      },
    );
  }

  /// After the address book or form was visited: re-read the list and keep
  /// the chosen address if it still exists, or take [picked].
  Future<void> addressesChanged({StoreAddress? picked}) async {
    final result = await getAddressesUseCase();
    result.fold((_) {}, (addresses) {
      final keepId = picked?.id ?? state.address?.id;
      final chosen =
          addresses.where((a) => a.id == keepId).firstOrNull ??
          addresses.where((a) => a.isDefault).firstOrNull ??
          addresses.firstOrNull;
      final changed = chosen?.id != state.address?.id;
      emit(state.copyWith(addresses: addresses, address: chosen));
      if (chosen == null) {
        emit(state.copyWith(quote: null));
      } else if (changed || state.quote == null || picked != null) {
        _resetOrder();
        _quote();
      }
    });
  }

  void selectAddress(StoreAddress address) {
    if (state.finished) return;
    final changed = address.id != state.address?.id;
    emit(state.copyWith(address: address));
    if (changed) {
      _resetOrder();
      _quote();
    }
  }

  Future<void> refreshQuote() => _quote();

  /// An order placed for the old address ships to the old address. A
  /// changed address therefore needs a new order, and a new attempt — the
  /// unpaid one is released by the server after 30 minutes.
  void _resetOrder() {
    if (state.order == null && _idempotencyKey == null) return;
    _idempotencyKey = null;
    emit(state.copyWith(order: null));
  }

  Future<void> _quote() async {
    final address = state.address;
    if (address == null) return;
    final generation = ++_quoteGeneration;
    emit(state.copyWith(quoting: true, quoteError: null));
    final result = await getQuoteUseCase(state.source, address.id);
    if (generation != _quoteGeneration) return;
    result.fold(
      (failure) => emit(
        state.copyWith(quoting: false, quoteError: storeErrorText(failure)),
      ),
      (quote) => emit(state.copyWith(quoting: false, quote: quote)),
    );
  }

  /// The Pay button.
  Future<void> pay() async {
    if (state.finished || state.placing || state.verifying) return;

    // Already have an order this visit: reopen Razorpay with it.
    final existing = state.order;
    if (existing != null) {
      _event(StoreCheckoutEvent.openPayment(existing));
      return;
    }

    final address = state.address;
    final quote = state.quote;
    if (address == null || quote == null || !quote.canPlaceOrder) return;

    _idempotencyKey ??= const Uuid().v4();
    emit(state.copyWith(placing: true));
    final result = await placeOrderUseCase(
      state.source,
      address.id,
      _idempotencyKey!,
    );
    result.fold(
      (failure) {
        emit(state.copyWith(placing: false));
        if (_mayHaveReachedServer(failure)) {
          // The order may exist. Keep the key: the retry gets the same
          // order back instead of a second one.
          _event(StoreCheckoutEvent.error(storeErrorText(failure)));
          return;
        }
        // A definite refusal — "… just sold out", empty cart, price gone.
        // That attempt is over; the next tap is a new one. Re-quote so
        // the page shows what changed.
        _idempotencyKey = null;
        _event(StoreCheckoutEvent.refused(storeErrorText(failure)));
        _quote();
      },
      (order) {
        if (order.alreadyPaid) {
          // A retry after a success. Nothing more to pay.
          emit(state.copyWith(placing: false, order: order, finished: true));
          _event(StoreCheckoutEvent.paid(order.orderNo));
          return;
        }
        emit(state.copyWith(placing: false, order: order));
        _event(StoreCheckoutEvent.openPayment(order));
      },
    );
  }

  /// P3, on every Razorpay success callback.
  Future<void> verify({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(verifying: true));
    final result = await verifyPaymentUseCase(
      order.orderNo,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
    result.fold(
      (failure) {
        if (storeStatusOf(failure) == 403) {
          // The signature did not verify: a failed payment. Same order.
          emit(state.copyWith(verifying: false));
          _event(StoreCheckoutEvent.failed(storeErrorText(failure)));
          return;
        }
        // We could not hear back. Razorpay says the money moved, and the
        // webhook places the order without us — so this is "being
        // confirmed", and paying again is the one thing not to offer.
        emit(state.copyWith(verifying: false, finished: true));
        _event(
          StoreCheckoutEvent.pending(
            'We received your payment and are confirming your order. '
            'It will appear in My orders shortly.',
            order.orderNo,
          ),
        );
      },
      (v) {
        if (v.paid) {
          emit(state.copyWith(verifying: false, finished: true));
          _event(StoreCheckoutEvent.paid(order.orderNo));
          return;
        }
        final message = v.message.toLowerCase();
        if (message.contains('being confirmed')) {
          emit(state.copyWith(verifying: false, finished: true));
          _event(StoreCheckoutEvent.pending(v.message, order.orderNo));
        } else if (message.contains('refund')) {
          // The order expired before the money arrived; refund is automatic.
          emit(state.copyWith(verifying: false, finished: true));
          _event(StoreCheckoutEvent.refunding(v.message, order.orderNo));
        } else {
          // "did not go through": retry with the same order.
          emit(state.copyWith(verifying: false));
          _event(
            StoreCheckoutEvent.failed(
              v.message.isEmpty
                  ? 'Payment did not go through. Nothing was charged.'
                  : v.message,
            ),
          );
        }
      },
    );
  }

  /// The SDK reported a decline. Nothing was charged; Pay reopens Razorpay
  /// with the same order.
  void paymentFailed(String message) =>
      _event(StoreCheckoutEvent.failed(message));

  void _event(StoreCheckoutEvent event) =>
      emit(state.copyWith(event: event, eventSeq: state.eventSeq + 1));

  /// Timeouts, no connection, 5xx: the request may have been acted on.
  static bool _mayHaveReachedServer(Failure failure) {
    if (failure is NetworkFailure || failure is UnknownFailure) return true;
    final status = storeStatusOf(failure);
    return status == null || status >= 500;
  }
}
