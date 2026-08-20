import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';

/// The red "LIVE" pill, with a dot that breathes so the badge reads as
/// happening-now rather than as a static label.
///
/// Driven by `isLive` at every call site — never by the `status` string,
/// which is a cached column and can sit at "Live" long after a class
/// has finished.
class WebinarLiveBadge extends StatefulWidget {
  /// Scales the whole pill. 1.0 is the card size; the detail hero uses
  /// a slightly larger one.
  final double scale;

  const WebinarLiveBadge({super.key, this.scale = 1.0});

  @override
  State<WebinarLiveBadge> createState() => _WebinarLiveBadgeState();
}

class _WebinarLiveBadgeState extends State<WebinarLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = Screen.getSize(7) * widget.scale;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(9) * widget.scale,
        vertical: Screen.getVerticalSize(4) * widget.scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_controller),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: AppColors.alwaysWhite,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(5) * widget.scale),
          Text(
            'LIVE',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(9) * widget.scale,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
