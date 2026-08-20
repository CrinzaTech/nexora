import 'package:flutter_bloc/flutter_bloc.dart';

/// A [Cubit] that quietly drops state updates once it has been closed.
///
/// The default [Cubit.emit] throws a `StateError` — *"Cannot emit new states
/// after calling close"* — the moment anything tries to push a state into a
/// closed cubit. That is the right behaviour in a test, where it catches a
/// genuine lifecycle bug. In production it means something far more ordinary:
///
///   1. The user opens a screen, which fires a request.
///   2. The network is slow, so the request is still in flight.
///   3. The user taps back. The route pops and the cubit is closed.
///   4. The response finally lands and the `await` resumes — into an `emit`
///      with nobody left to listen to it.
///
/// There is no screen to update, so there is nothing to do and nothing has
/// gone wrong. But the throw escapes the un-awaited future it happens inside,
/// reaches the zone, and lands in Crashlytics as an unhandled error. That
/// single pattern accounted for the largest issue in the crash dashboard —
/// 26 events across 11 users, none of which actually closed the app.
///
/// Swallowing the emit is the correct answer rather than a workaround: the
/// state is genuinely unobservable once [close] has run, so dropping it and
/// discarding it are the same thing.
///
/// Cubits that need to *skip the work itself* — cancelling a poll loop,
/// avoiding a second network round-trip — should still check [isClosed]
/// explicitly at their await points; this base class only makes the final
/// hand-off safe. See `WebinarRoomCubit` and `LiveClassCubit` for that
/// heavier-weight pattern.
abstract class SafeCubit<S> extends Cubit<S> {
  SafeCubit(super.initialState);

  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}
