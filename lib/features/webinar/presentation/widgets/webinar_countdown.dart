import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nexora/features/webinar/data/models/webinar_model.dart';

/// Rebuilds [builder] as the wait shrinks, handing it the time left
/// before [webinar] starts.
///
/// The remaining time comes from the payload's `startsInSeconds` plus
/// the time elapsed locally since it arrived (see [WebinarItem.receivedAt]),
/// so a device whose clock is days out still counts down correctly.
///
/// The tick adapts: once per second inside the last hour, where seconds
/// are the part that moves, and once a minute before that — a class two
/// days out does not need 172,800 rebuilds.
class WebinarCountdown extends StatefulWidget {
  final WebinarItem webinar;
  final Widget Function(BuildContext context, Duration remaining) builder;

  /// Called once when the countdown reaches zero — the moment worth
  /// re-reading the gate, since the class is about to go live.
  final VoidCallback? onElapsed;

  const WebinarCountdown({
    super.key,
    required this.webinar,
    required this.builder,
    this.onElapsed,
  });

  @override
  State<WebinarCountdown> createState() => _WebinarCountdownState();
}

class _WebinarCountdownState extends State<WebinarCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _elapsedFired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.webinar.timeUntilStart;
    _schedule(isInitial: true);
  }

  @override
  void didUpdateWidget(covariant WebinarCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh hands us a new payload with a new `receivedAt`; restart
    // against it rather than keep counting from the stale one.
    if (oldWidget.webinar.receivedAt != widget.webinar.receivedAt ||
        oldWidget.webinar.slug != widget.webinar.slug) {
      _elapsedFired = false;
      _remaining = widget.webinar.timeUntilStart;
      _schedule(isInitial: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [isInitial] marks a (re)start against a fresh payload rather than a
  /// timer reaching zero.
  ///
  /// It is what stops a live webinar from refreshing itself forever: a
  /// live class arrives with `startsInSeconds: 0`, so the countdown is
  /// already spent on arrival — firing [WebinarCountdown.onElapsed]
  /// there would refetch, hand back another zero payload, and go round
  /// again. Only an actual 0-crossing means something changed.
  void _schedule({bool isInitial = false}) {
    _timer?.cancel();
    if (_remaining <= Duration.zero) {
      if (isInitial) {
        _elapsedFired = true;
      } else {
        _fireElapsed();
      }
      return;
    }
    final interval = _remaining.inHours < 1
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _timer = Timer.periodic(interval, (_) => _tick(interval));
  }

  void _tick(Duration interval) {
    if (!mounted) return;
    final next = widget.webinar.timeUntilStart;
    setState(() => _remaining = next);

    // Crossing into the final hour needs the faster tick, and hitting
    // zero needs the timer stopped — both are a reschedule.
    if (next <= Duration.zero ||
        (interval.inMinutes == 1 && next.inHours < 1)) {
      _schedule();
    }
  }

  void _fireElapsed() {
    if (_elapsedFired) return;
    _elapsedFired = true;
    final callback = widget.onElapsed;
    if (callback == null) return;
    // Deferred: this can run from initState, and the callback typically
    // pokes a cubit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
