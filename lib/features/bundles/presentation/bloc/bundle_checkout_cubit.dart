import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/services/course_access_events.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/usecases/bundle_usecases.dart';

part 'bundle_checkout_state.dart';
part 'bundle_checkout_cubit.freezed.dart';

/// Buying a bundle: P1 to price it, Razorpay to collect, P2 to unlock.
///
/// **The courses are unlocked by P2 and by nothing else.** A completed
/// Razorpay sheet is not a purchase, so every success callback goes
/// through [verify] before anything says "unlocked". And once Razorpay
/// has reported success, nothing here ever offers to pay again: a
/// pending or unreachable P2 becomes [BundleCheckoutState.confirming],
/// which polls B2 for `isPurchased` — the webhook unlocks the courses
/// even when this app never hears back.
///
/// The Razorpay sheet belongs to the widget (a plugin with listeners and
/// a disposal contract); this cubit owns the API calls and what each of
/// their answers means.
class BundleCheckoutCubit extends SafeCubit<BundleCheckoutState> {
  final CreateBundleOrderUseCase createBundleOrderUseCase;
  final VerifyBundlePaymentUseCase verifyBundlePaymentUseCase;
  final GetBundleDetailUseCase getBundleDetailUseCase;

  /// BUNDLE_API.md §9: poll B2 every 5 s for up to a minute.
  static const Duration pollInterval = Duration(seconds: 5);
  static const int maxPolls = 12;

  BundleCheckoutCubit({
    required this.createBundleOrderUseCase,
    required this.verifyBundlePaymentUseCase,
    required this.getBundleDetailUseCase,
  }) : super(const BundleCheckoutState.idle());

  /// Bumped by every new poll so an older loop stops on its next tick.
  int _pollGeneration = 0;

  /// P1 — only ever on a Pay tap. [shownTotal] is the `totalPayable` the
  /// learner was looking at; if the server now prices it differently the
  /// new breakdown is shown for confirmation before any sheet opens.
  Future<void> start(int bundleId, {required double shownTotal}) async {
    emit(const BundleCheckoutState.creatingOrder());

    final result = await createBundleOrderUseCase(bundleId);
    result.fold(
      (failure) {
        switch (_statusOf(failure)) {
          case 403 || 404:
            // Off sale, a course changed, they already own everything,
            // or the bundle is gone. Retrying cannot help; the page
            // re-reads B2, which says which.
            emit(BundleCheckoutState.refused(failure.message));
          case 400:
            // Misconfigured price — only the educator can fix it.
            emit(BundleCheckoutState.failed(failure.message, false));
          default:
            emit(BundleCheckoutState.failed(failure.message, true));
        }
      },
      (order) {
        final moved = (order.amountRupees - shownTotal).abs() >= 0.005;
        emit(
          moved
              ? BundleCheckoutState.priceChanged(order)
              : BundleCheckoutState.orderReady(order),
        );
      },
    );
  }

  /// The learner accepted the new price from [BundleCheckoutState.priceChanged].
  void confirmNewPrice(BundleOrder order) =>
      emit(BundleCheckoutState.orderReady(order));

  /// P2 — fired on **every** Razorpay success callback.
  Future<void> verify(
    int bundleId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    emit(const BundleCheckoutState.verifying());

    final result = await verifyBundlePaymentUseCase(
      bundleId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );

    result.fold(
      (failure) {
        final status = _statusOf(failure);
        if (status == 403) {
          // Signature or order mismatch. Nothing unlocked, and whether
          // money moved is unclear — support, not a retry.
          emit(
            const BundleCheckoutState.failed(
              'Payment verification failed.',
              false,
            ),
          );
          return;
        }
        if (status == 404) {
          emit(BundleCheckoutState.failed(failure.message, false));
          return;
        }
        // A network error or a 5xx **after** Razorpay succeeded: the
        // money may well have left their account. Treat as pending —
        // the webhook will unlock the courses.
        _confirm(
          bundleId,
          "We're confirming your payment. This can take a minute.",
        );
      },
      (payment) {
        if (payment.paid) {
          _unlocked(payment.message);
        } else if (payment.pending) {
          _confirm(bundleId, payment.message);
        } else {
          // An authoritative "not captured" — the message explains.
          emit(BundleCheckoutState.failed(payment.message, true));
        }
      },
    );
  }

  /// Captured but not yet confirmed. Polls B2 until `isPurchased`, and
  /// after a minute settles on [BundleCheckoutState.stillPending].
  Future<void> _confirm(int bundleId, String message) async {
    final generation = ++_pollGeneration;
    emit(
      BundleCheckoutState.confirming(
        message.isEmpty ? "We're confirming your payment." : message,
      ),
    );

    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(pollInterval);
      if (isClosed || generation != _pollGeneration) return;

      final result = await getBundleDetailUseCase(bundleId);
      if (isClosed || generation != _pollGeneration) return;

      final purchased = result.fold((_) => false, (d) => d.card.isPurchased);
      if (purchased) {
        _unlocked('Payment successful. Your courses are unlocked.');
        return;
      }
    }

    emit(
      const BundleCheckoutState.stillPending(
        "Your payment is still being confirmed. We'll notify you once "
        'your courses are unlocked. Please do not pay again.',
      ),
    );
  }

  /// "Check again" from [BundleCheckoutState.stillPending]: another minute
  /// of polling. Deliberately not a way back to checkout.
  Future<void> recheck(int bundleId) =>
      _confirm(bundleId, "We're checking your payment again.");

  void _unlocked(String message) {
    CourseAccessEvents.notifyUnlocked();
    emit(
      BundleCheckoutState.paid(
        message.isEmpty
            ? 'Payment successful. Your courses are unlocked.'
            : message,
      ),
    );
  }

  /// The sheet was closed. Nothing charged; the next Pay gets the same
  /// order back.
  void cancelled() => emit(const BundleCheckoutState.idle());

  /// The SDK reported a decline. Nothing charged.
  void declined(String message) =>
      emit(BundleCheckoutState.failed(message, true));

  void reset() {
    _pollGeneration++;
    emit(const BundleCheckoutState.idle());
  }

  @override
  Future<void> close() {
    _pollGeneration++;
    return super.close();
  }

  int? _statusOf(Failure failure) => failure.maybeWhen(
    server: (_, statusCode) => statusCode,
    orElse: () => null,
  );
}
