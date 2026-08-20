import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// Shared surface treatments — the "premium" layer.
///
/// Depth on a light page comes almost entirely from drop shadows. On a
/// near-black page that stops working: a black shadow on a black
/// background is invisible, which is why naive dark themes look flat no
/// matter how many shadows you stack.
///
/// So the dark treatment leans on three things instead:
///
///   1. **Tonal separation** — the card surface sits a real step above
///      the scaffold (see the branding config's dark palette).
///   2. **A lit top edge** — a 1px warm hairline where light would catch
///      the lip of a raised panel. This is what actually reads as
///      "raised" in the dark.
///   3. **A wide, dim bloom** — a low-alpha halo, not a hard shadow.
///
/// Light mode keeps a conventional soft shadow and dials the accent
/// right back, since a white card has nothing for a gilt edge to catch
/// and an obvious one just looks like a yellow border.
class AppDecorations {
  AppDecorations._();

  /// Ambient + contact shadows for a raised surface.
  static List<BoxShadow> cardShadow() {
    if (AppColors.isDark) {
      return [
        // Deep ambient shadow — separates the card from the page.
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.55),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        // Warm bloom. Negative spread keeps it behind the card rather
        // than leaking out as a visible ring.
        BoxShadow(
          color: AppColors.accentGlow,
          blurRadius: 28,
          spreadRadius: -8,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.black.withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: AppColors.black.withValues(alpha: 0.03),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Standard raised panel — section cards, sheets, list containers.
  static BoxDecoration card({double? radius}) => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius ?? AppSizes.radiusL),
    // A hairline border does the heavy lifting in the dark, where the
    // shadow can't. Kept almost invisible in light mode.
    border: Border.all(
      color: AppColors.isDark
          ? AppColors.alwaysWhite.withValues(alpha: 0.06)
          : AppColors.black.withValues(alpha: 0.03),
      width: 1,
    ),
    boxShadow: cardShadow(),
  );

  /// Hairline for a raised card.
  ///
  /// Dark mode is where the gilt shows: a warm rim reads as a lit edge
  /// on a near-black page, which a neutral grey border can't do. Kept at
  /// a low alpha on purpose — pushed harder it stops looking like an
  /// edge catching light and starts looking like a gold ring drawn
  /// around a box.
  ///
  /// [lightColor] is whatever border the card already used; light mode
  /// keeps it, so adopting this is a no-op there.
  static Border cardBorder({Color? lightColor, double width = 1}) => Border.all(
    color: AppColors.isDark
        ? AppColors.accent.withValues(alpha: 0.20)
        : (lightColor ?? AppColors.black.withValues(alpha: 0.03)),
    width: width,
  );

  /// Rim gradient for glass surfaces — the floating navbar.
  ///
  /// Brighter than [cardBorder] because the navbar is a single hero
  /// element rather than one of a dozen cards down a scroll, and because
  /// a translucent blurred fill gives the rim less to sit against.
  /// Peaks in the middle of each edge so it reads as a curved highlight.
  static LinearGradient rimGradient() {
    final tone = AppColors.isDark ? AppColors.accent : AppColors.primary;
    return LinearGradient(
      colors: [
        tone.withValues(alpha: AppColors.isDark ? 0.16 : 0.12),
        tone.withValues(alpha: AppColors.isDark ? 0.55 : 0.40),
        tone.withValues(alpha: AppColors.isDark ? 0.16 : 0.12),
      ],
    );
  }

  /// Drop shadow for a floating element (navbar, FAB). Carries the brand
  /// halo plus, in the dark, a warm bloom to match the rim.
  static List<BoxShadow> floatingShadow() => [
    BoxShadow(
      color: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.20 : 0.14,
      ),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    if (AppColors.isDark)
      BoxShadow(
        color: AppColors.accent.withValues(alpha: 0.14),
        blurRadius: 30,
        spreadRadius: -6,
        offset: const Offset(0, 6),
      ),
  ];

  /// Halo for a primary call-to-action, so the main action on a screen
  /// glows rather than sitting flat on the surface.
  static List<BoxShadow> ctaGlow() => [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: AppColors.isDark ? 22 : 16,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];

  /// The lit lip along the top edge of a raised surface.
  ///
  /// Painted as a gradient that peaks in the middle and fades to nothing
  /// at both corners — a hard line running corner to corner reads as a
  /// border, not a highlight.
  static LinearGradient topEdgeHighlight() => LinearGradient(
    colors: [
      AppColors.accent.withValues(alpha: 0.0),
      AppColors.accentHairline,
      AppColors.accentSoft.withValues(alpha: AppColors.isDark ? 0.5 : 0.22),
      AppColors.accentHairline,
      AppColors.accent.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
  );
}

/// A raised panel carrying the full treatment from [AppDecorations]:
/// surface fill, hairline border, layered shadow, and the lit top edge.
///
/// The top edge has to be a separate layer rather than a `Border` —
/// Flutter rejects a non-uniform border combined with a border radius,
/// and a uniform gold border would ring the whole card.
class PremiumSurface extends StatelessWidget {
  final Widget child;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Defaults to filling the available width, because a section card in
  /// a `Column` would otherwise shrink-wrap its content — most of the
  /// app's columns leave `crossAxisAlignment` at its centred default.
  /// Pass null for a card that should size to its child.
  final double? width;

  /// Set false for surfaces that shouldn't advertise themselves —
  /// nested panels, or a card already sitting on a coloured backdrop.
  final bool showTopEdge;

  const PremiumSurface({
    super.key,
    required this.child,
    this.radius,
    this.padding,
    this.margin,
    this.width = double.infinity,
    this.showTopEdge = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppSizes.radiusL;
    return Container(
      width: width,
      margin: margin,
      decoration: AppDecorations.card(radius: r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          children: [
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
            if (showTopEdge)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppDecorations.topEdgeHighlight(),
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

/// Frosted-glass bottom sheet for the auth flow (login / OTP).
///
/// Translucent white alone is *conditional* glass: over a colourful
/// backdrop it reads as a panel, over a white backdrop it disappears
/// entirely. Three layers make the sheet legible on ANY background:
///
///   1. **Backdrop blur** — frosts whatever sits behind, so even a
///      busy image can't fight the content on top.
///   2. **Ambient drop shadow above the top edge** — a shadow is the
///      one cue that survives a pure-white backdrop, where both the
///      translucent fill and the white rim go invisible.
///   3. **Rim + top-edge highlight** — sells "glass" over dark or
///      saturated backdrops where the shadow alone reads as a card.
///
/// The fill is a vertical gradient (denser at the top, airier below)
/// through [AppColors.white], so dark mode automatically swaps to the
/// dark surface tone.
class GlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double topRadius;

  const GlassSheet({
    super.key,
    required this.child,
    this.padding,
    this.topRadius = 50,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(topRadius),
      topRight: Radius.circular(topRadius),
    );
    final isDark = AppColors.isDark;

    // Every *visible* border side must carry the SAME colour. Flutter
    // only paints a non-uniform border alongside a borderRadius when the
    // set of visible colours has exactly one entry; give the top a
    // brighter alpha than the sides and `Border.paint` throws, which
    // aborts painting of the whole subtree — a blank sheet. The lit lip
    // is layered on separately below instead.
    final rim = AppColors.alwaysWhite.withValues(alpha: isDark ? 0.22 : 0.75);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Ambient lift — keeps the sheet edge visible on a white
          // backdrop where fill and rim provide zero contrast.
          BoxShadow(
            color: AppColors.black.withValues(alpha: isDark ? 0.50 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
          // Faint brand halo hugging the lip, so the lift feels lit
          // rather than smudged.
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          // passthrough hands the incoming constraints to the fill
          // container unchanged, so adding this Stack can't alter the
          // sheet's geometry.
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: isDark ? 0.74 : 0.72),
                      AppColors.white.withValues(alpha: isDark ? 0.60 : 0.54),
                    ],
                  ),
                  borderRadius: radius,
                  border: Border(
                    top: BorderSide(width: 1.5, color: rim),
                    left: BorderSide(width: 1.5, color: rim),
                    right: BorderSide(width: 1.5, color: rim),
                  ),
                ),
                child: child,
              ),
              // Brighter lip along the flat top. The enclosing ClipRRect
              // trims it to the rounded shape, so it fades out over the
              // shoulders instead of running corner to corner.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.alwaysWhite.withValues(alpha: 0.0),
                          AppColors.alwaysWhite.withValues(
                            alpha: isDark ? 0.34 : 0.95,
                          ),
                          AppColors.alwaysWhite.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
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
