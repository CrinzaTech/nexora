import 'package:argon_buttons_flutter_fix/argon_buttons_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../theme/app_typography.dart';
import '../theme/screen.dart';

class CustomOutlinedActionButton extends StatelessWidget {
  final Function(
    Function startLoading,
    Function stopLoading,
    ButtonState btnState,
  )
  onTap;
  final String name;
  final bool showAction;
  final bool isFormFilled;
  final Color? disabledColor;
  final Color? disabledTextColor;
  final Color? borderColor;
  final IconData? icon;
  final MainAxisAlignment? iconAlignment;
  final Widget? leading;
  final bool isWhiteThemed;
  final bool shouldAnimate;
  final bool? isLoaded;
  final bool isError;
  final double? buttonWidth;
  final double? buttonHeight;
  final double? borderWidth;
  final double? borderRadius;

  const CustomOutlinedActionButton({
    super.key,
    required this.onTap,
    required this.name,
    required this.isFormFilled,
    this.isError = false,
    this.showAction = true,
    this.leading,
    this.isWhiteThemed = false,
    this.shouldAnimate = true,
    this.isLoaded,
    this.buttonWidth,
    this.buttonHeight,
    this.disabledColor,
    this.disabledTextColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.icon,
    this.iconAlignment,
  });

  // Figma neumorphism tokens — keep them next to the widget so the design
  // intent stays self-documenting and any future tweak is one-stop.
  static const Color _gradientBorderColor = Color(0xFFAFAAFF);
  static const Color _innerShadowTop = Color(0x66B6B2FF); // ~40% — top glow
  static const Color _innerShadowBottom = Color(0x0F000000); // ~6% — bottom

  @override
  Widget build(BuildContext context) {
    final alignment = iconAlignment ?? MainAxisAlignment.start;
    final radius = borderRadius ?? 50.0;
    final cornerRadius = BorderRadius.circular(radius);

    return LayoutBuilder(
      builder: (context, constraints) {
        // ArgonButton interpolates between this width and its own height
        // internally on tap (`a + (b - a) * t`) — feeding it `double.infinity`
        // makes that lerp evaluate to NaN even at rest. Resolve to the
        // parent's actual bounded width instead, falling back to the screen
        // width only if the parent itself is unbounded.
        final resolvedWidth =
            buttonWidth ??
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : Screen.width);

        return _buildButton(
          context,
          resolvedWidth,
          alignment,
          radius,
          cornerRadius,
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    double resolvedWidth,
    MainAxisAlignment alignment,
    double radius,
    BorderRadius cornerRadius,
  ) {
    return Container(
      // Outer fill = the linear gradient border. We pad by 1px and host a
      // white fill inside so the gradient becomes a hairline outline. A soft
      // drop-shadow underneath gives the button the lifted feel from the
      // reference without competing with the inner shadows.
      decoration: BoxDecoration(
        borderRadius: cornerRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _gradientBorderColor.withValues(alpha: 0.15),
            _gradientBorderColor,
            _gradientBorderColor.withValues(alpha: 0.15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientBorderColor.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth ?? 1),
      child: ClipRRect(
        // Slightly tighter radius so the inner fill nests cleanly inside
        // the gradient ring without a 1px halo.
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          children: [
            // Tappable surface — ArgonButton handles loader + tap states.
            Container(
              color: AppColors.white,
              child: ArgonButton(
                height: buttonHeight ?? 56,
                width: resolvedWidth,
                borderRadius: radius,
                loader: Container(
                  height: 28,
                  width: 28,
                  padding: const EdgeInsets.all(2),
                  child: SpinKitDoubleBounce(
                    color: isWhiteThemed
                        ? AppColors.primary
                        : AppColors.primary,
                  ),
                ),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Icon on START
                      if (icon != null &&
                          alignment == MainAxisAlignment.start) ...[
                        Icon(
                          icon,
                          color: isFormFilled
                              ? AppColors.primary
                              : disabledTextColor ?? AppColors.grey500,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Leading widget
                      if (leading != null) leading!,
                      if (leading != null) const SizedBox(width: 12),
                      // Icon + Text centered together (for CENTER alignment)
                      if (icon != null &&
                          alignment == MainAxisAlignment.center) ...[
                        Icon(
                          icon,
                          color: isFormFilled
                              ? AppColors.primary
                              : disabledTextColor ?? AppColors.grey500,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Text (always centered)
                      Expanded(
                        child: AutoSizeText(
                          name,
                          maxLines: 1,
                          minFontSize: 12,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            color: isFormFilled
                                ? AppColors.primary
                                : disabledTextColor ?? AppColors.grey500,
                            fontSize: Screen.getFontSize(14),
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                        ),
                      ),
                      // Spacing after text for END icon
                      if (icon != null && alignment == MainAxisAlignment.end)
                        const SizedBox(width: 12),
                      // Icon on END
                      if (icon != null && alignment == MainAxisAlignment.end)
                        Icon(
                          icon,
                          color: isFormFilled
                              ? AppColors.primary
                              : disabledTextColor ?? AppColors.grey500,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Two stacked inner shadows. IgnorePointer lets taps pass
            // through to the ArgonButton underneath.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DualInnerShadowPainter(
                    topShadowColor: _innerShadowTop,
                    topOffset: const Offset(0, 6),
                    topBlur: 9,
                    bottomShadowColor: _innerShadowBottom,
                    bottomOffset: const Offset(0, -4),
                    bottomBlur: 8,
                    borderRadius: BorderRadius.circular(radius - 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints two stacked inset shadows in a single pass — used by the outlined
/// button to produce the neumorphic "pressed-in" look.
class _DualInnerShadowPainter extends CustomPainter {
  final Color topShadowColor;
  final Offset topOffset;
  final double topBlur;
  final Color bottomShadowColor;
  final Offset bottomOffset;
  final double bottomBlur;
  final BorderRadius borderRadius;

  _DualInnerShadowPainter({
    required this.topShadowColor,
    required this.topOffset,
    required this.topBlur,
    required this.bottomShadowColor,
    required this.bottomOffset,
    required this.bottomBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    InnerShadowPainter(
      color: topShadowColor,
      blurRadius: topBlur,
      offset: topOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
    InnerShadowPainter(
      color: bottomShadowColor,
      blurRadius: bottomBlur,
      offset: bottomOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_DualInnerShadowPainter old) =>
      topShadowColor != old.topShadowColor ||
      topOffset != old.topOffset ||
      topBlur != old.topBlur ||
      bottomShadowColor != old.bottomShadowColor ||
      bottomOffset != old.bottomOffset ||
      bottomBlur != old.bottomBlur ||
      borderRadius != old.borderRadius;
}
