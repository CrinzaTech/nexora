import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/data/models/webinar_payment_model.dart';
import 'package:nexora/features/webinar/domain/usecases/webinar_payment_usecases.dart';

part 'webinar_checkout_state.dart';
part 'webinar_checkout_cubit.freezed.dart';

/// Buying a seat at a paid webinar: P1 to price it, Razorpay to collect,
/// P2 to make it real.
///
/// **The seat is created by P2 and by nothing else.** A completed
/// Razorpay sheet is not a purchase as far as this API is concerned, so
/// every success callback goes through [verify] before anything routes
/// the learner anywhere.
///
/// The Razorpay sheet itself is not driven from here — that is a plugin
/// with its own listeners and a disposal contract, so it belongs to the
/// widget. This cubit owns the two API calls and the decision each of
/// their answers implies.
class WebinarCheckoutCubit extends SafeCubit<WebinarCheckoutState> {
  final CreateWebinarOrderUseCase createWebinarOrderUseCase;
  final VerifyWebinarPaymentUseCase verifyWebinarPaymentUseCase;

  WebinarCheckoutCubit({
    required this.createWebinarOrderUseCase,
    required this.verifyWebinarPaymentUseCase,
  }) : super(const WebinarCheckoutState.idle());

  /// P1. Only ever called for a webinar the detail payload said is not
  /// free and not already registered — the endpoint 400s on a free one
  /// and 403s on one they own, and both of those are branching mistakes
  /// rather than things to show a learner.
  Future<void> start(String slug) async {
    emit(const WebinarCheckoutState.creatingOrder());

    final result = await createWebinarOrderUseCase(slug);
    result.fold((failure) {
      final message = failure.message;
      switch (_statusOf(failure)) {
        case 403 when _mentionsAlreadyPaid(message):
          // They own it. Not an error — go to the room.
          emit(WebinarCheckoutState.alreadyPaid(message));
        case 403:
          // Any other 403 is the server refusing to sell: the workshop
          // filled, or the host closed the link, while this screen was
          // open. Matched on the status rather than the wording — the
          // client is told no seat counts precisely so it cannot
          // second-guess this, and string-matching "fully booked" would
          // break the first time somebody rephrases it.
          emit(WebinarCheckoutState.refused(message));
        case 400 when _mentionsFree(message):
          // The webinar is free after all (a discount landed between the
          // detail read and the tap). Nothing to pay, so let them in;
          // the join call seats them exactly as it would have anyway.
          emit(const WebinarCheckoutState.paid(null));
        default:
          emit(WebinarCheckoutState.failed(message, true));
      }
    }, (order) => emit(WebinarCheckoutState.orderReady(order)));
  }

  /// P2 — fired on **every** Razorpay success callback. Until it answers
  /// `paid: true`, nothing has happened as far as this API is concerned.
  Future<void> verify(
    String slug, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    emit(const WebinarCheckoutState.verifying());

    final result = await verifyWebinarPaymentUseCase(
      slug,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );

    result.fold(
      (failure) {
        switch (_statusOf(failure)) {
          case 403:
            // The signature did not verify. Whether money moved is
            // unclear, so no retry: a second attempt can only produce a
            // second charge to refund. Support, with the receipt.
            emit(WebinarCheckoutState.failed(failure.message, false));
          case 500:
            // We could not reach Razorpay. The money may well have left
            // their account while we cannot confirm it — the one case
            // where offering "pay again" would be actively harmful.
            emit(WebinarCheckoutState.unresolved(failure.message));
          default:
            emit(WebinarCheckoutState.failed(failure.message, true));
        }
      },
      (payment) {
        if (payment.paid) {
          emit(WebinarCheckoutState.paid(payment.state));
          return;
        }
        // A 200 with `paid: false` is an authoritative "the money did
        // not move", not a request that failed. Nothing was charged, so
        // retrying is exactly right.
        emit(WebinarCheckoutState.failed(payment.message, true));
      },
    );
  }

  /// The sheet was closed without paying. Charges nothing, and the
  /// CREATED order it leaves behind is harmless — P1 will hand back a
  /// fresh one next time.
  void cancelled() => emit(const WebinarCheckoutState.idle());

  /// The SDK reported a decline. Nothing was charged.
  void declined(String message) =>
      emit(WebinarCheckoutState.failed(message, true));

  void reset() => emit(const WebinarCheckoutState.idle());

  bool _mentionsAlreadyPaid(String message) =>
      message.toLowerCase().contains('already paid');

  bool _mentionsFree(String message) =>
      message.toLowerCase().contains('is free');

  int? _statusOf(Failure failure) => failure.maybeWhen(
    server: (_, statusCode) => statusCode,
    orElse: () => null,
  );
}
