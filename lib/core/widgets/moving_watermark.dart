import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import 'package:nexora/core/theme/app_typography.dart';

/// Anti-piracy overlay: drifts the student's name + phone number across
/// the video surface at constant speed so a screen recording always
/// carries the viewer's identity. Shared by the lecture player and the
/// live-class player. Render inside an [IgnorePointer] over the video.
class MovingWatermark extends StatefulWidget {
  final String name;
  final String phone;

  const MovingWatermark({super.key, required this.name, required this.phone});

  @override
  State<MovingWatermark> createState() => _MovingWatermarkState();
}

class _MovingWatermarkState extends State<MovingWatermark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _animation;
  final Random _random = Random();

  Alignment _startAlignment = Alignment.topLeft;
  Alignment _endAlignment = Alignment.bottomRight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _animation = AlignmentTween(
      begin: _startAlignment,
      end: _endAlignment,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startAlignment = _endAlignment;
        _endAlignment = Alignment(
          _random.nextDouble() * 1.6 -
              0.8, // Bound to -0.8 .. 0.8 to avoid excessive clipping
          _random.nextDouble() * 1.6 - 0.8,
        );
        _setNewAnimation(context.size ?? const Size(400, 300));
        _controller.forward(from: 0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setNewAnimation(context.size ?? const Size(400, 300));
        _controller.forward();
      }
    });
  }

  void _setNewAnimation(Size size) {
    // Calculate physical pixel distance
    final dx = (_endAlignment.x - _startAlignment.x) * size.width / 2;
    final dy = (_endAlignment.y - _startAlignment.y) * size.height / 2;
    final distance = sqrt(dx * dx + dy * dy);

    // Constant speed of movement: 40 pixels per second
    const double speed = 40.0;
    final double durationSeconds = distance / speed;

    _controller.duration = Duration(
      milliseconds: (durationSeconds * 1000).toInt().clamp(1000, 30000),
    );

    _animation = AlignmentTween(
      begin: _startAlignment,
      end: _endAlignment,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.name.isEmpty && widget.phone.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Align(
          alignment: _animation.value,
          child: Opacity(
            opacity: 0.4,
            child: Text(
              "${widget.name}\n${widget.phone}",
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.alwaysWhite,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                decoration: TextDecoration.none,
                height: 1.2,
                shadows: [const Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ),
        );
      },
    );
  }
}
