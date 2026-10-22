import 'dart:async';

/// App-wide "the learner just gained courses" signal.
///
/// A purchase made on one screen has to show up on screens that are
/// already built and kept alive — the Enrolled tab above all, whose
/// cubit otherwise only refetches on pull-to-refresh. Rather than every
/// checkout knowing which cubits to poke, the checkout announces the
/// unlock here and whoever cares listens.
abstract final class CourseAccessEvents {
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// Fires once per confirmed unlock. Broadcast: late listeners miss
  /// past events, which is fine — they fetch fresh when they are built.
  static Stream<void> get unlocked => _controller.stream;

  /// Call only once the server has confirmed the unlock — never from a
  /// payment callback alone.
  static void notifyUnlocked() => _controller.add(null);
}
