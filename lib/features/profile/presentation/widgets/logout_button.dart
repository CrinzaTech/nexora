import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:flutter/material.dart';

/// Filled red logout pill with a neumorphic effect tuned for the error
/// palette — same depth language as the primary [CustomActionButton]
/// but with red highlights instead of its purple-calibrated tokens.
///
/// Layered build:
///   1. Outer gradient ring (`#7C0C0C` 15% → 100% → 15%, horizontal so
///      the dark band reads as a soft emboss line on the top/bottom
///      edges instead of a hard bar on the sides).
///   2. Solid `AppColors.error` fill.
///   3. Twin inner shadows (Figma spec):
///        - Top:    `#FFCDCF`,        offset (0, 4),  blur 6
///        - Bottom: `#FFD8D8` @ 18%,  offset (0, -3), blur 6
///   4. Coloured outer drop-shadow lifts the pill off the surface.
class LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const LogoutButton({super.key, required this.onTap});

  // Figma spec tokens — exact values from the destructive elevated
  // button frame.
  static const Color _gradientBorderColor = Color(0xFF7C0C0C);
  static const Color _innerShadowTop = Color(0xFFFFCDCF);
  static const Color _innerShadowBottom = Color(0xFFFFD8D8);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(50);
    final innerRadius = BorderRadius.circular(49);
    final rh = ResponsiveHelper.of(context);

    return SizedBox(
      width: rh.isLargeScreen ? Screen.width * .4 : Screen.width * .6,
      height: rh.isLargeScreen
          ? Screen.getVerticalSize(40)
          : Screen.getVerticalSize(50),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _gradientBorderColor.withValues(alpha: 0.15),
              _gradientBorderColor,
              _gradientBorderColor.withValues(alpha: 0.15),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.30),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: Stack(
            children: [
              Material(
                color: AppColors.error,
                child: InkWell(
                  onTap: onTap,
                  splashColor: AppColors.alwaysWhite.withValues(alpha: 0.18),
                  highlightColor: AppColors.alwaysWhite.withValues(alpha: 0.08),
                  child: Center(
                    child: Text(
                      'Logout',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                        fontSize: rh.isLargeScreen
                            ? Screen.getFontSize(11)
                            : Screen.getFontSize(15),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              // Twin inner shadows — IgnorePointer so taps still reach
              // the InkWell beneath.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LogoutInnerShadowPainter(
                      topColor: _innerShadowTop,
                      topOffset: const Offset(0, 4),
                      topBlur: 6,
                      bottomColor: _innerShadowBottom.withValues(alpha: 0.18),
                      bottomOffset: const Offset(0, -3),
                      bottomBlur: 6,
                      borderRadius: innerRadius,
                    ),
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

/// Stacks two [InnerShadowPainter] passes to give the logout button the
/// pressed-in neumorphic look in a single foreground paint.
class _LogoutInnerShadowPainter extends CustomPainter {
  final Color topColor;
  final Offset topOffset;
  final double topBlur;
  final Color bottomColor;
  final Offset bottomOffset;
  final double bottomBlur;
  final BorderRadius borderRadius;

  _LogoutInnerShadowPainter({
    required this.topColor,
    required this.topOffset,
    required this.topBlur,
    required this.bottomColor,
    required this.bottomOffset,
    required this.bottomBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    InnerShadowPainter(
      color: topColor,
      blurRadius: topBlur,
      offset: topOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
    InnerShadowPainter(
      color: bottomColor,
      blurRadius: bottomBlur,
      offset: bottomOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_LogoutInnerShadowPainter old) =>
      topColor != old.topColor ||
      topOffset != old.topOffset ||
      topBlur != old.topBlur ||
      bottomColor != old.bottomColor ||
      bottomOffset != old.bottomOffset ||
      bottomBlur != old.bottomBlur ||
      borderRadius != old.borderRadius;
}
