import 'package:nexora/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A narrow diagonal highlight that travels across its parent on a loop.
///
/// Renders *only* the streak, sized to fill whatever box it is given — place
/// it in a [Stack] above the surface it should sweep, inside whatever clip
/// that surface already uses. Keeping it overlay-only is what lets the same
/// widget light a gradient card, a label pill and the app-bar band without
/// each caller having to hand over its own painting.
///
/// It reads as light catching a surface, so it only belongs on a saturated
/// one. Over a white or near-white panel a white streak has nothing to
/// brighten and simply does not show.
class ShineSweep extends StatefulWidget {
  /// Staggers the start so a row of them ripples instead of flashing in
  /// unison. Pass the item's position in its list.
  final int index;

  /// Peak strength at the centre of the streak. The edges always fade to
  /// zero, so this is the brightest point rather than a flat overlay.
  final double opacity;

  /// One pass, edge to edge.
  final Duration period;

  /// Dead time between passes. Without it the sweep reads as a spinner
  /// rather than an occasional glint.
  final Duration pause;

  /// Corner the streak travels from.
  final AlignmentGeometry begin;

  /// Corner it travels toward.
  final AlignmentGeometry end;

  const ShineSweep({
    super.key,
    this.index = 0,
    this.opacity = 0.28,
    this.period = const Duration(milliseconds: 2800),
    this.pause = const Duration(milliseconds: 1600),
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  /// Streak width as a fraction of the travel. Much wider and it stops
  /// reading as a highlight and starts looking like the surface itself
  /// changing colour.
  static const double _halfWidth = 0.18;

  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    Future.delayed(Duration(milliseconds: widget.index * 320), () {
      if (!mounted) return;
      _loop();
    });
  }

  void _loop() async {
    while (mounted) {
      await _ctrl.forward(from: 0);
      await Future.delayed(widget.pause);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(gradient: _streak(_anim.value)),
        ),
      ),
    );
  }

  /// Maps [t] so the streak's centre starts and ends off the box — entry and
  /// exit stay clean instead of the highlight popping in at full strength.
  LinearGradient _streak(double t) {
    final double centre = -0.6 + t * 2.2;
    return LinearGradient(
      begin: widget.begin,
      end: widget.end,
      stops: [
        (centre - _halfWidth).clamp(0.0, 1.0),
        centre.clamp(0.0, 1.0),
        (centre + _halfWidth).clamp(0.0, 1.0),
      ],
      colors: [
        AppColors.alwaysWhite.withValues(alpha: 0.0),
        AppColors.alwaysWhite.withValues(alpha: widget.opacity),
        AppColors.alwaysWhite.withValues(alpha: 0.0),
      ],
    );
  }
}
