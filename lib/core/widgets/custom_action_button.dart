import 'package:argon_buttons_flutter_fix/argon_buttons_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../theme/app_typography.dart';
import '../theme/screen.dart';

/// Visual tone for [CustomActionButton] — bundles the four colours and
/// the inner-shadow geometry the neumorphism look needs (fill, hairline
/// border gradient tint, top inner glow, bottom inner shadow + their
/// per-shadow offset / blur) so each Figma variant can be expressed
/// with a single value at call sites.
///
/// Pass any of the predefined tones via [CustomActionButton.tone],
/// or build a custom one if a screen needs a brand-specific shade.
class CustomActionButtonTone {
  /// Solid fill on the inner surface (the colour you "see" the button as).
  final Color background;

  /// Hairline border gradient tint — usually a lighter version of
  /// [background] so the rim reads as a soft glow.
  final Color borderGradient;

  /// Top inner shadow / glow — pulls the button forwards visually.
  /// Lighter than [background].
  final Color innerShadowTop;

  /// Bottom inner shadow — usually black with low alpha; together with
  /// [innerShadowTop] it makes the surface look pressed-in.
  final Color innerShadowBottom;

  /// Geometry of the top glow — Figma sometimes calls for tighter
  /// shadows (smaller Y, smaller blur) on lighter tones.
  final Offset innerShadowTopOffset;
  final double innerShadowTopBlur;

  /// Geometry of the bottom inset.
  final Offset innerShadowBottomOffset;
  final double innerShadowBottomBlur;

  const CustomActionButtonTone({
    required this.background,
    required this.borderGradient,
    required this.innerShadowTop,
    this.innerShadowBottom = const Color(0x66000000),
    this.innerShadowTopOffset = const Offset(0, 8),
    this.innerShadowTopBlur = 12,
    this.innerShadowBottomOffset = const Offset(0, -6),
    this.innerShadowBottomBlur = 10,
  });

  /// Default brand button — same look the button has shipped with since
  /// the neumorphism polish (purple/indigo with light-purple glow).
  /// `static final` (not `const`) because the background pulls from
  /// brand-driven [AppColors.primary], which is itself runtime-init.
  static final CustomActionButtonTone primary = CustomActionButtonTone(
    background: AppColors.primary,
    borderGradient: const Color(0xFFAFAAFF),
    innerShadowTop: const Color(0xFFB6B2FF),
  );

  /// Success / confirm — green (used for "Rewatch", "Mark complete").
  /// Geometry + colours from the Figma success-button spec:
  ///   bg #39B72D, border #A2FF9A (gradient 15→100→15),
  ///   top inset #98FA8F  Y4  blur6,
  ///   bottom inset #000  25%  Y-3  blur6.
  static const CustomActionButtonTone success = CustomActionButtonTone(
    background: Color(0xFF39B72D),
    borderGradient: Color(0xFFA2FF9A),
    innerShadowTop: Color(0xFF98FA8F),
    innerShadowBottom: Color(0x40000000),
    innerShadowTopOffset: Offset(0, 4),
    innerShadowTopBlur: 6,
    innerShadowBottomOffset: Offset(0, -3),
    innerShadowBottomBlur: 6,
  );

  /// Destructive / error — red (used for "Renew Course", "Delete").
  static const CustomActionButtonTone error = CustomActionButtonTone(
    background: AppColors.error,
    borderGradient: AppColors.errorLight,
    innerShadowTop: Color(0xFFFCA5A5),
  );

  /// Warning — amber/orange (used for cautions, recoverable risks).
  static const CustomActionButtonTone warning = CustomActionButtonTone(
    background: AppColors.warning,
    borderGradient: AppColors.warningLight,
    innerShadowTop: Color(0xFFFCD34D),
  );

  /// Informational — blue.
  static const CustomActionButtonTone info = CustomActionButtonTone(
    background: AppColors.info,
    borderGradient: AppColors.infoLight,
    innerShadowTop: Color(0xFF93C5FD),
  );
}

class CustomActionButton extends StatelessWidget {
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
  final bool isOutlined;
  final Widget? leading;
  final bool isWhiteThemed;
  final bool shouldAnimate;
  final bool? isLoaded;
  final bool isError;
  final double? buttonWidth;
  final double? buttonHeight;
  final double? borderWidth;
  final bool? showBorderColor;
  final Color? backgroundColor;

  /// Visual tone bundle. Defaults to [CustomActionButtonTone.primary] so
  /// existing call sites render unchanged.
  ///
  /// When [backgroundColor] is also passed it wins over `tone.background`
  /// — the border / inner-shadow tints still come from the tone, which
  /// keeps the neumorphism look coherent even with a custom fill.
  /// Nullable because the default (`CustomActionButtonTone.primary`)
  /// is brand-derived → not const-evaluable. `null` resolves to
  /// [CustomActionButtonTone.primary] inside [build].
  final CustomActionButtonTone? tone;

  const CustomActionButton({
    super.key,
    required this.onTap,
    required this.name,
    required this.isFormFilled,
    this.isError = false,
    this.showAction = true,
    this.isOutlined = false,
    this.leading,
    this.isWhiteThemed = false,
    this.shouldAnimate = true,
    this.isLoaded,
    this.buttonWidth,
    this.buttonHeight,
    this.disabledColor,
    this.disabledTextColor,
    this.borderWidth,
    this.showBorderColor,
    this.backgroundColor,
    // Nullable + resolved in build() because the default value
    // (`CustomActionButtonTone.primary`) is now `static final` —
    // optional-param defaults must be const-evaluable, which a
    // runtime-init brand colour isn't.
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? CustomActionButtonTone.primary;
    final bgColor = backgroundColor ?? effectiveTone.background;
    final radius = BorderRadius.circular(50);
    final innerRadius = BorderRadius.circular(50 - 1);
    final showNeumorphic = isFormFilled;

    return Container(
      // Outer fill = the linear gradient ring. Padded by 1px around the
      // solid inner fill so the gradient becomes a hairline border.
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: showNeumorphic
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  effectiveTone.borderGradient.withValues(alpha: 0.15),
                  effectiveTone.borderGradient,
                  effectiveTone.borderGradient.withValues(alpha: 0.15),
                ],
              )
            : null,
        // Disabled state retains the original look (faded fill, no border).
        color: showNeumorphic
            ? null
            : (disabledColor ?? bgColor.withValues(alpha: 0.4)),
        boxShadow: [
          if (showNeumorphic)
            // Halo in the button's own tone. Pushed harder on a dark
            // canvas — the same alpha that reads as a soft glow against
            // white all but disappears against near-black.
            BoxShadow(
              color: bgColor.withValues(alpha: AppColors.isDark ? 0.45 : 0.30),
              blurRadius: AppColors.isDark ? 20 : 14,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      padding: EdgeInsets.all(showNeumorphic ? (borderWidth ?? 1) : 0),
      child: ClipRRect(
        borderRadius: showNeumorphic ? innerRadius : radius,
        child: Stack(
          children: [
            // Tappable surface with the solid tone fill.
            Container(
              color: showNeumorphic ? bgColor : Colors.transparent,
              child: ArgonButton(
                height: buttonHeight ?? Screen.getVerticalSize(50),
                width: buttonWidth ?? MediaQuery.of(context).size.width,
                borderRadius: 50.0,
                loader: Container(
                  height: 28,
                  width: 28,
                  padding: const EdgeInsets.all(2),
                  child: SpinKitDoubleBounce(
                    // Same rule as the label: the spinner sits on the
                    // filled tone, so it must not follow the surface.
                    color: isWhiteThemed || isOutlined
                        ? AppColors.primary
                        : AppColors.alwaysWhite,
                  ),
                ),
                onTap: onTap,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) leading!,
                      if (leading != null) const SizedBox(width: 8),
                      Flexible(
                        child: AutoSizeText(
                          name,
                          maxLines: 1,
                          minFontSize: 12,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            color: isFormFilled
                                ? AppColors.alwaysWhite
                                : (disabledTextColor ??
                                      AppColors.alwaysWhite.withValues(alpha: 0.7)),
                            fontSize: Screen.getFontSizeCapped(16),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dual inner shadows — only when active. IgnorePointer keeps
            // taps flowing through to the ArgonButton beneath.
            if (showNeumorphic)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DualInnerShadowPainter(
                      topShadowColor: effectiveTone.innerShadowTop,
                      topOffset: effectiveTone.innerShadowTopOffset,
                      topBlur: effectiveTone.innerShadowTopBlur,
                      bottomShadowColor: effectiveTone.innerShadowBottom,
                      bottomOffset: effectiveTone.innerShadowBottomOffset,
                      bottomBlur: effectiveTone.innerShadowBottomBlur,
                      borderRadius: innerRadius,
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

/// Stacks two inset-shadow passes for the filled button's pressed-in look.
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
