import 'dart:async';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScrollingTitle — plain single-style scrolling text
// ─────────────────────────────────────────────────────────────────────────────

/// Renders [text] as a plain [Text] when it fits.
/// Switches to a Marquee when it overflows:
///   • Holds 1 s → scrolls → pauses 2 s at start → repeats.
///   No dot separator. No fading edges.
class ScrollingTitle extends StatelessWidget {
  final String text;
  final TextStyle style;

  /// Scroll speed in logical pixels per second. Defaults to 60 px/s.
  final double velocity;

  const ScrollingTitle({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 60.0,
  });

  double _textWidth() {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return painter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final textW = _textWidth();

        if (textW <= availableWidth) {
          return Text(text, style: style, maxLines: 1);
        }

        final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.25);
        return SizedBox(
          height: lineHeight + 2,
          child: Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            velocity: velocity,
            startAfter: const Duration(seconds: 1),
            pauseAfterRound: const Duration(seconds: 2),
            blankSpace: 40.0,
            accelerationDuration: const Duration(milliseconds: 400),
            accelerationCurve: Curves.easeIn,
            decelerationDuration: const Duration(milliseconds: 400),
            decelerationCurve: Curves.easeOut,
            fadingEdgeStartFraction: 0.0,
            fadingEdgeEndFraction: 0.0,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RichScrollingTitle — mixed-style (bold/regular) scrolling rich text
// ─────────────────────────────────────────────────────────────────────────────

/// Like [ScrollingTitle] but accepts a [TextSpan] tree so you can mix
/// styles (e.g. regular + bold) within the same scrolling line.
///
/// When the rich text fits it renders as a static [Text.rich].
/// When it overflows a custom [SingleChildScrollView] + [AnimationController]
/// animates it with the same hold → scroll → pause → repeat behaviour.
class RichScrollingTitle extends StatefulWidget {
  final TextSpan span;

  /// Scroll speed in logical pixels per second. Defaults to 60 px/s.
  final double velocity;

  const RichScrollingTitle({
    super.key,
    required this.span,
    this.velocity = 60.0,
  });

  @override
  State<RichScrollingTitle> createState() => _RichScrollingTitleState();
}

class _RichScrollingTitleState extends State<RichScrollingTitle> {
  final ScrollController _sc = ScrollController();
  bool _scrolling = false;

  /// Measures the full single-line width of [span].
  double _textWidth() {
    final painter = TextPainter(
      text: widget.span,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return painter.size.width;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginLoop());
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _beginLoop() async {
    // Initial hold before first scroll.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _loop();
  }

  Future<void> _loop() async {
    if (!mounted || !_sc.hasClients) return;
    
    // The exact distance we need to scroll to complete one full cycle
    final distance = _textWidth() + 40.0;
    if (distance <= 0) return;

    // Scroll at [velocity] px/s.
    final ms = (distance / widget.velocity * 1000).round();
    
    await _sc.animateTo(
      distance,
      duration: Duration(milliseconds: ms),
      curve: Curves.linear,
    );
    if (!mounted) return;

    // Jump back to start instantly to complete the seamless loop.
    _sc.jumpTo(0);

    // Pause at start before next scroll (matches pauseAfterRound).
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _loop(); // repeat
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textW = _textWidth();

        if (textW <= constraints.maxWidth) {
          // Fits — plain rich text, no animation.
          return Text.rich(widget.span, maxLines: 1);
        }

        // Overflows — animated scroll container.
        final rootStyle = widget.span.style;
        final lineHeight =
            (rootStyle?.fontSize ?? 14) * (rootStyle?.height ?? 1.25);

        return SizedBox(
          height: lineHeight + 2,
          child: SingleChildScrollView(
            controller: _sc,
            scrollDirection: Axis.horizontal,
            // User cannot manually scroll — only the animation drives it.
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Text.rich(widget.span, maxLines: 1),
                const SizedBox(width: 40.0), // blankSpace
                Text.rich(widget.span, maxLines: 1),
                // Extra buffer to ensure maxScrollExtent > distance,
                // preventing Flutter from clamping the animation.
                const SizedBox(width: 100.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
