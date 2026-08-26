import 'dart:math';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Full-screen "party" celebration — ribbon streamers fired from both
/// bottom corners plus falling confetti, behind a scale-in message card.
///
/// Inserted on the **root** [Overlay] so it draws above bottom sheets,
/// dialogs and the app bar, and survives the host widget rebuilding
/// (e.g. a course-detail refetch right after enrolment). Auto-dismisses
/// after [duration]; tapping anywhere dismisses it early.
///
/// Dependency-free — the whole effect is one [AnimationController]
/// driving a single [CustomPainter].
class CelebrationOverlay {
  CelebrationOverlay._();

  /// The entry currently on screen, if any. Guards against two
  /// celebrations stacking when a state emits twice.
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    String emoji = '🎉',
    String? quote,
    Duration duration = const Duration(milliseconds: 3400),
  }) {
    if (_current != null) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationScene(
        title: title,
        message: message,
        emoji: emoji,
        quote: quote,
        duration: duration,
        onDismiss: () {
          if (_current != entry) return;
          _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _CelebrationScene extends StatefulWidget {
  final String title;
  final String? message;
  final String emoji;
  final String? quote;
  final Duration duration;
  final VoidCallback onDismiss;

  const _CelebrationScene({
    required this.title,
    required this.message,
    required this.emoji,
    required this.quote,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_CelebrationScene> createState() => _CelebrationSceneState();
}

class _CelebrationSceneState extends State<_CelebrationScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Streamer> _streamers;
  late final List<_Confetti> _confetti;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    final random = Random();
    // Two cannons — one per bottom corner — firing inwards and up.
    _streamers = [
      ...List.generate(9, (i) => _Streamer.cannon(random, fromLeft: true)),
      ...List.generate(9, (i) => _Streamer.cannon(random, fromLeft: false)),
    ];
    _confetti = List.generate(36, (_) => _Confetti.random(random));

    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          child: Stack(
            children: [
              // Party layer — painted full-bleed behind the card.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _PartyPainter(
                      streamers: _streamers,
                      confetti: _confetti,
                      progress: _controller.value,
                    ),
                  ),
                ),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.55, end: 1.0),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: _CelebrationCard(
                    title: widget.title,
                    message: widget.message,
                    emoji: widget.emoji,
                    quote: widget.quote,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Message card — emoji, headline, and the optional detail lines.
// ─────────────────────────────────────────────────────────────
class _CelebrationCard extends StatelessWidget {
  final String title;
  final String? message;
  final String emoji;
  final String? quote;

  const _CelebrationCard({
    required this.title,
    required this.message,
    required this.emoji,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gentle bob so the emoji doesn't read as a static image while
          // the confetti moves around it.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 52)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h5SemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
          if (quote != null) ...[
            const SizedBox(height: 14),
            Text(
              quote!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Party colours shared by both effects.
// ─────────────────────────────────────────────────────────────
final _partyColors = <Color>[
  AppColors.primary,
  AppColors.successDark,
  const Color(0xFFFFC107),
  const Color(0xFFFF6B6B),
  const Color(0xFF4DD0E1),
  const Color(0xFFAB47BC),
];

// ─────────────────────────────────────────────────────────────
// Ribbon streamer — a curly party ribbon launched on a ballistic arc
// from one of the bottom corners, trailing a wavy tail behind it.
// ─────────────────────────────────────────────────────────────
class _Streamer {
  /// Launch origin as a fraction of the canvas.
  final double originX;
  final double originY;

  /// Launch direction in radians (0 = right, pi/2 = straight up).
  final double angle;

  /// Travel speed in "canvas heights per unit of progress".
  final double speed;

  /// Fraction of the timeline to wait before launching, so the ribbons
  /// spread out instead of firing as one clump.
  final double delay;

  final double waveAmplitude;
  final double waveFrequency;
  final double strokeWidth;

  /// Length of the trailing tail, in units of the ribbon's own travel.
  final double tail;

  final Color color;

  const _Streamer({
    required this.originX,
    required this.originY,
    required this.angle,
    required this.speed,
    required this.delay,
    required this.waveAmplitude,
    required this.waveFrequency,
    required this.strokeWidth,
    required this.tail,
    required this.color,
  });

  /// A ribbon fired from the bottom-left or bottom-right corner, aimed
  /// inwards and upwards across the screen.
  factory _Streamer.cannon(Random random, {required bool fromLeft}) {
    // 42°..86° off horizontal, mirrored for the right-hand cannon.
    final spread = (42 + random.nextDouble() * 44) * pi / 180;
    return _Streamer(
      originX: fromLeft ? -0.02 : 1.02,
      originY: 1.02,
      angle: fromLeft ? spread : pi - spread,
      speed: 0.85 + random.nextDouble() * 0.75,
      delay: random.nextDouble() * 0.18,
      waveAmplitude: 5 + random.nextDouble() * 12,
      waveFrequency: 1.5 + random.nextDouble() * 2.5,
      strokeWidth: 2.5 + random.nextDouble() * 3.5,
      tail: 0.16 + random.nextDouble() * 0.16,
      color: _partyColors[random.nextInt(_partyColors.length)],
    );
  }

  /// Ballistic position at local time [t] (0..1 after the delay).
  Offset positionAt(double t, Size size) {
    const gravity = 2.4;
    final unit = size.height;
    final dx = cos(angle) * speed * t * unit;
    final dy = (-sin(angle) * speed * t + 0.5 * gravity * t * t) * unit;
    return Offset(originX * size.width + dx, originY * size.height + dy);
  }
}

// ─────────────────────────────────────────────────────────────
// Confetti — small shapes drifting down from above the top edge.
// ─────────────────────────────────────────────────────────────
class _Confetti {
  final double x;
  final double startDelay;
  final double fallSpeed;
  final double size;
  final double swayAmplitude;
  final double swayFrequency;
  final double rotationSpeed;

  /// 0 = rectangle, 1 = circle, 2 = thin ribbon curl.
  final int shape;

  final Color color;

  const _Confetti({
    required this.x,
    required this.startDelay,
    required this.fallSpeed,
    required this.size,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.rotationSpeed,
    required this.shape,
    required this.color,
  });

  factory _Confetti.random(Random random) {
    return _Confetti(
      x: random.nextDouble(),
      startDelay: random.nextDouble() * 0.35,
      fallSpeed: 0.7 + random.nextDouble() * 0.7,
      size: 6 + random.nextDouble() * 7,
      swayAmplitude: 10 + random.nextDouble() * 24,
      swayFrequency: 2 + random.nextDouble() * 3,
      rotationSpeed:
          (random.nextBool() ? 1 : -1) * (2 + random.nextDouble() * 5),
      shape: random.nextInt(3),
      color: _partyColors[random.nextInt(_partyColors.length)],
    );
  }
}

class _PartyPainter extends CustomPainter {
  final List<_Streamer> streamers;
  final List<_Confetti> confetti;
  final double progress;

  _PartyPainter({
    required this.streamers,
    required this.confetti,
    required this.progress,
  });

  /// Everything fades together over the last fifth of the timeline so
  /// the effect settles instead of vanishing mid-flight.
  double get _globalFade =>
      progress < 0.8 ? 1.0 : (1 - (progress - 0.8) / 0.2).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    _paintStreamers(canvas, size);
    _paintConfetti(canvas, size);
  }

  void _paintStreamers(Canvas canvas, Size size) {
    for (final s in streamers) {
      if (progress <= s.delay) continue;
      final t = ((progress - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);

      // Sample the trajectory backwards from the ribbon head to build
      // its tail, offsetting each sample perpendicular to the direction
      // of travel by a sine wave — that curl is what reads as "ribbon"
      // rather than "line".
      const samples = 14;
      final points = <Offset>[];
      for (var i = 0; i <= samples; i++) {
        final f = i / samples;
        final tt = t - s.tail * f;
        if (tt < 0) break;
        final p = s.positionAt(tt, size);
        final ahead = s.positionAt((tt + 0.01).clamp(0.0, 1.0), size);
        final dir = ahead - p;
        final len = dir.distance;
        if (len == 0) {
          points.add(p);
          continue;
        }
        // Unit normal to the travel direction.
        final nx = -dir.dy / len;
        final ny = dir.dx / len;
        final wave =
            sin(f * s.waveFrequency * 2 * pi + t * 9) * s.waveAmplitude;
        points.add(Offset(p.dx + nx * wave, p.dy + ny * wave));
      }
      if (points.length < 2) continue;

      // Drawn as fading segments so the tail thins out behind the head.
      for (var i = 0; i < points.length - 1; i++) {
        final f = i / (points.length - 1);
        final paint = Paint()
          ..color = s.color.withValues(alpha: (1 - f) * _globalFade)
          ..strokeWidth = s.strokeWidth * (1 - f * 0.55)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  void _paintConfetti(Canvas canvas, Size size) {
    for (final c in confetti) {
      if (progress <= c.startDelay) continue;
      final t = (progress - c.startDelay) / (1 - c.startDelay);
      // Start above the top edge so pieces drift in rather than pop in.
      final y = -0.1 * size.height + t * c.fallSpeed * size.height * 1.35;
      if (y > size.height) continue;
      final x =
          c.x * size.width + sin(t * c.swayFrequency * 2 * pi) * c.swayAmplitude;

      final paint = Paint()
        ..color = c.color.withValues(alpha: _globalFade)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * c.rotationSpeed);
      switch (c.shape) {
        case 1:
          canvas.drawCircle(Offset.zero, c.size / 2, paint);
        case 2:
          // Thin curl — a stroked arc that reads as a ribbon offcut.
          final curl = Paint()
            ..color = paint.color
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset.zero,
              width: c.size * 1.6,
              height: c.size,
            ),
            0,
            pi * 1.4,
            false,
            curl,
          );
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: c.size,
                height: c.size * 0.6,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PartyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
