import 'dart:ui';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:flutter/material.dart';

/// Nav Item Model
class NavItem {
  final String label;
  final String icon;
  final String activeIcon;
  final String route;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

/// Floating Navbar — iOS 26 "Liquid Glass" + inner neumorphism, sourced
/// verbatim from the Figma spec for the bottom bar.
///
/// Spec tokens:
///   - Fill:           #FFFFFF @ 23%
///   - Border:         1px linear gradient #6C63FF 12% → 40% → 12%
///   - Inner shadow:   #F1F1FF, offset (-2, 3), blur 10
///   - Background blur: 12 (Figma spec is 33; dialled down to 12 because
///     a fullscreen BackdropFilter runs every frame on every screen — on
///     a Snapdragon 4-series at 60 Hz that's ~12-16 ms of frame budget.
///     Sigma 12 still reads as glass without burning the whole budget.)
///
/// Layered build:
///   1. Outer drop shadow on the wrapping Container so it isn't clipped
///      by the ClipRRect that masks the backdrop blur.
///   2. ClipRRect → BackdropFilter — the heavy blur is what produces the
///      iOS Liquid Glass colour-bleed effect.
///   3. Translucent white fill + gradient border for the glass surface.
///   4. CustomPaint overlay paints the inner shadow on top of the fill,
///      giving the pressed-in neumorphic depth without disturbing the
///      blurred backdrop. Wrapped in IgnorePointer so taps still reach
///      the nav-item gestures beneath.
class FloatingNavbar extends StatelessWidget {
  final List<NavItem> items;
  final String activeRoute;
  final Function(String route) onDestinationSelected;

  const FloatingNavbar({
    super.key,
    required this.items,
    required this.activeRoute,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final radius = BorderRadius.circular(40);
    // Figma tokens, brand-derived so the navbar re-skins with
    // [AppColors.primary]:
    //   Border gradient: primary @ 12% → 40% → 12%
    //   Inner shadow:    primary @ 8% — soft brand-tinted highlight
    //                    replacing the hardcoded #F1F1FF lavender
    //                    wash. Stays subtle so the glass effect
    //                    underneath still reads as the dominant
    //                    surface treatment.
    // Rim + halo come from AppDecorations so the navbar picks up the
    // same gilt edge the cards use in dark mode; light mode keeps the
    // brand-indigo rim it always had.
    final innerShadowColor = AppColors.primary.withValues(
      alpha: AppColors.isDark ? 0.05 : 0.08,
    );
    // The active icon and label are foregrounds sitting on the glass, so
    // they take the contrast-corrected primary. On dark, a brand colour
    // dark enough to disappear against the surface gets lifted until it
    // is readable; on light this is [AppColors.primary] verbatim.
    final activeTint = AppColors.primaryContent;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: rh.maxNavBarWidth),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppDecorations.floatingShadow(),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                children: [
                  // Glass surface — translucent fill + gradient border.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      // The glass fill needs more body on a near-black page:
                      // at 23 % the blurred backdrop shows straight through
                      // and the bar stops reading as a surface at all.
                      color: AppColors.white.withValues(
                        alpha: AppColors.isDark ? 0.55 : 0.23,
                      ),
                      borderRadius: radius,
                      border: GradientBorder(
                        gradient: AppDecorations.rimGradient(),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: items.map((item) {
                        final isActive = item.route == activeRoute;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!isActive) onDestinationSelected(item.route);
                          },
                          child: AnimatedScale(
                            scale: isActive ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: Screen.getFontSizeCapped(22),
                                  child: DecoratedBox(
                                    // Backlight behind the active glyph. A
                                    // glow cannot rescue a low-contrast
                                    // colour on its own — that is what
                                    // [AppColors.primaryContent] is for —
                                    // but once the glyph is legible this
                                    // makes it read as lit rather than
                                    // merely coloured. Tinted with the brand
                                    // rather than white: a white halo behind
                                    // a coloured glyph desaturates its edges
                                    // and reads as a smudge.
                                    decoration: isActive && AppColors.isDark
                                        ? BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: activeTint.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: -3,
                                              ),
                                            ],
                                          )
                                        : const BoxDecoration(),
                                    child: Image.asset(
                                      isActive ? item.activeIcon : item.icon,
                                      // Tint both states from AppColors so the
                                      // navbar re-skins with the brand. Assumes
                                      // the icon PNGs are monochrome glyphs —
                                      // a multi-colour asset would smear under
                                      // this tint.
                                      color: isActive
                                          ? activeTint
                                          : AppColors.mutedTextPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: Screen.getVerticalSize(3)),
                                Text(
                                  item.label,
                                  style: AppTypography.bodyTextMedium.copyWith(
                                    fontSize: Screen.getFontSizeCapped(11),
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    // Inactive labels share the icons' muted
                                    // tone. They used grey300, which sits at
                                    // 3.6:1 on the dark surface — dimmer than
                                    // the glyph right above them, and under AA
                                    // for 11px text.
                                    color: isActive
                                        ? activeTint
                                        : AppColors.mutedTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Inner shadow overlay — Figma spec: (-2, 3), blur 10,
                  // colour #F1F1FF. IgnorePointer so the icons beneath stay
                  // tappable.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: InnerShadowPainter(
                          color: innerShadowColor,
                          blurRadius: 10,
                          offset: const Offset(-2, 3),
                          borderRadius: radius,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
