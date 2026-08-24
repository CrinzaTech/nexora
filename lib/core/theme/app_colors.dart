import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'branding_config.dart';

/// App color palette.
///
/// Brand-driven values (primary / secondary tones) come from
/// [currentBranding] — flip a single constant in
/// `branding_config.dart` to re-skin every screen that consumes
/// these. Neutral / semantic colours (greys, success, error, etc.)
/// stay as direct constants since they don't change per client.
///
/// The brand tokens are `static final` rather than `static const`
/// because Dart can't const-evaluate field access on a const object
/// (`currentBranding.primary` isn't a constant expression even
/// though `currentBranding` itself is). The runtime cost is one
/// lazy init per token, which is negligible and unblocks the
/// centralized config pattern.
class AppColors {
  AppColors._();

  // ============================================
  // ACTIVE BRIGHTNESS — drives every dynamic token below
  // ============================================
  // The app was written against `AppColors.*` constants rather than
  // `Theme.of(context)`, so a `themeMode` flip alone would repaint
  // almost nothing. Routing the neutral tokens through this one flag
  // makes all ~410 existing call sites theme-aware without touching
  // them.
  //
  // [applyBrightness] is called by `AppTheme.lightTheme` / `darkTheme`
  // as they build, so the flag is always in step with the ThemeData
  // MaterialApp is about to paint with.
  //
  // Note this is deliberately global rather than an InheritedWidget:
  // the call sites are `static` field reads with no BuildContext in
  // scope, and threading a context through 94 files is exactly the
  // refactor this design avoids. The trade-off is that widgets must be
  // rebuilt for a change to show — which is what ThemeCubit driving
  // MaterialApp's `themeMode` already guarantees.
  static Brightness _brightness = Brightness.light;

  /// True while the dark palette is active.
  static bool get isDark => _brightness == Brightness.dark;

  /// Point every dynamic token at the light or dark half of the
  /// palette. Called from [AppTheme]; app code should change the theme
  /// through `ThemeCubit`, not by calling this directly.
  static void applyBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  /// Picks between the light and dark value of a token.
  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ============================================
  // CONTRAST — keeping a fixed brand colour legible
  // ============================================

  /// WCAG 2.1 contrast ratio between two opaque colours, 1.0 → 21.0.
  ///
  /// AA wants 4.5 for body text, 3.0 for large text and for graphics
  /// such as icon glyphs and focus rings.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// [fg] lifted until it clears [target] contrast against [bg].
  ///
  /// Only the HSL lightness moves — hue and saturation are left alone so
  /// the result still reads as the same brand colour rather than an
  /// unrelated pastel. Returns [fg] untouched when it already passes,
  /// and bottoms out at pure white rather than looping forever.
  ///
  /// Deliberately one-directional: it lightens. That is what a dark
  /// surface needs, and every caller here is a foreground on dark.
  static Color legibleOn(Color fg, Color bg, {double target = 4.5}) {
    if (contrastRatio(fg, bg) >= target) return fg;
    final hsl = HSLColor.fromColor(fg);
    for (double l = hsl.lightness; l < 1.0; l += 0.02) {
      final candidate = hsl.withLightness(l).toColor();
      if (contrastRatio(candidate, bg) >= target) return candidate;
    }
    return alwaysWhite;
  }

  // ============================================
  // PRIMARY COLORS — brand-driven via BrandingConfig
  // ============================================
  static final Color primary = currentBranding.primary;

  /// Brand primary, safe to use as a **foreground** — an icon tint, a
  /// label, a link, a focus ring — on the active surface.
  ///
  /// Unlike every neutral token here, [primary] is a single fixed brand
  /// value with no dark half, because it also serves as a *background*
  /// (filled buttons) where it must stay exactly on-brand. That leaves
  /// foreground uses stranded on a near-black surface: the default
  /// indigo lands at 3.99:1 against `darkSurface`, and an org whose
  /// brand colour is genuinely dark — a deep navy, say — lands near
  /// 1.4:1, which is invisible.
  ///
  /// Rather than hand-maintaining a second brand token per org, this
  /// lifts the primary just far enough to clear AA for small text. Light
  /// mode returns [primary] untouched: a brand colour chosen to work on
  /// a white page already has the contrast it needs.
  static Color get primaryContent =>
      isDark ? (_primaryContentDark ??= legibleOn(primary, white)) : primary;

  /// Memoised because the dark surface it is measured against is a
  /// compile-time constant, so the search only ever needs running once.
  static Color? _primaryContentDark;
  // static final Color primaryLight = currentBranding.primaryLight;
  // static final Color primaryDark = currentBranding.primaryDark;

  static final Color secondary = currentBranding.secondary;
  // static final Color secondaryLight = currentBranding.secondaryLight;
  // static final Color secondaryDark = currentBranding.secondaryDark;

  static const Color videoPlayerBgColor = Color(0xFF0D1B2A);

  // ============================================
  // PREMIUM ACCENT — the gilt edge
  // ============================================
  /// Warm metallic accent. Same hue in both themes; what changes is how
  /// hard it's pushed — see [accentHairline] / [accentGlow].
  static Color get accent => currentBranding.accent;
  static Color get accentSoft => currentBranding.accentSoft;

  /// Strength of the 1px top-edge highlight on a raised surface.
  ///
  /// On a dark canvas the lip is what sells the depth, so it runs
  /// noticeably brighter. On white there is barely anything for it to
  /// catch, and pushing it turns the card into a yellow-rimmed box.
  static Color get accentHairline =>
      accent.withValues(alpha: isDark ? 0.55 : 0.20);

  /// Wide, very low-alpha bloom sitting under a raised surface.
  static Color get accentGlow => accent.withValues(alpha: isDark ? 0.13 : 0.06);

  /// Halo behind a primary call-to-action.
  static Color get primaryGlow =>
      primary.withValues(alpha: isDark ? 0.34 : 0.22);

  // ============================================
  // TEXT COLORS — dynamic
  // ============================================
  static Color get textPrimary =>
      _pick(const Color(0xFF0D1B2A), currentBranding.darkTextPrimary);
  static Color get textSecondary =>
      _pick(const Color(0xFF545e6a), currentBranding.darkTextSecondary);
  // static const Color textTertiary = Color(0xFF64748B);
  static Color get mutedTextPrimary =>
      _pick(const Color(0xFF7B8FA6), currentBranding.darkTextMuted);
  // static const Color buttonPrimaryLight = Color(0xFFA78BFA);
  // static const Color buttonPrimaryDark = Color(0xFF4F46E5);

  // ============================================
  // Component-specific colors
  // ============================================
  static const Color switchThumbColor = Color(0xFFFFFFFF);
  static const Color switchBackgroundColor = Color(
    0xFF6C63FF,
  ); // Brand primary indigo

  static const Color discountBadgeBackground = Color(0xFF5AC550);

  // ============================================
  // NEUTRAL COLORS
  // ============================================
  // The greys are a *surface ramp*: low numbers are backgrounds, high
  // numbers are foregrounds. Dark mode inverts that ramp so a call
  // site written as "pale background" stays a background and one
  // written as "near-black text" stays legible text.

  /// Literal black — does not flip. Use for scrims and shadows.
  static const Color black = Color(0xFF000000);

  /// Literal white — does not flip. Use for content painted **on top
  /// of a brand colour** (button labels on [primary], icons over the
  /// hero gradient), where the backdrop is the same in both themes.
  static const Color alwaysWhite = Color(0xFFFFFFFF);

  /// Default panel/card surface. White in light mode,
  /// `darkSurface` in dark. For content sitting on a brand colour use
  /// [alwaysWhite] instead — that must not flip.
  static Color get white =>
      _pick(const Color(0xFFFFFFFF), currentBranding.darkSurface);

  static Color get grey50 =>
      _pick(const Color(0xFFF8FAFC), currentBranding.darkScaffold);
  static Color get grey100 =>
      _pick(const Color(0xFFF1F5F9), currentBranding.darkSurfaceElevated);
  static Color get grey200 =>
      _pick(const Color(0xFFCBD5E1), currentBranding.darkDivider);
  static Color get grey300 =>
      _pick(const Color(0xFF94A3B8), const Color(0xFF64748B));
  static Color get grey400 =>
      _pick(const Color(0xFF64748B), const Color(0xFF94A3B8));
  static Color get grey500 =>
      _pick(const Color(0xFF475569), const Color(0xFFB4C0CF));
  static Color get grey600 =>
      _pick(const Color(0xFF334155), const Color(0xFFCBD5E1));
  static Color get grey700 =>
      _pick(const Color(0xFF1E293B), const Color(0xFFE2E8F0));
  static Color get grey800 =>
      _pick(const Color(0xFF0F172A), const Color(0xFFF1F5F9));
  static Color get grey900 =>
      _pick(const Color(0xFF020617), const Color(0xFFF8FAFC));

  // ============================================
  // SEMANTIC COLORS
  // ============================================
  // The hues themselves read fine on both canvases and stay const.
  // Only the pale `*Background` tints flip — at 4 % of the hue they
  // stay a whisper of colour instead of a white slab on dark.
  static const Color success = Color(0xFF10B981); // Teal
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  static Color get successBackground =>
      _pick(const Color(0xFFECFDF5), success.withValues(alpha: 0.16));

  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);
  static Color get errorBackground =>
      _pick(const Color(0xFFFEF2F2), error.withValues(alpha: 0.16));

  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  static Color get warningBackground =>
      _pick(const Color(0xFFFFF7ED), warning.withValues(alpha: 0.16));

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);
  static Color get infoBackground =>
      _pick(const Color(0xFFEFF6FF), info.withValues(alpha: 0.16));

  // ============================================
  // SOCIAL COLORS
  // ============================================
  static const Color googleRed = Color(0xFFEA4335);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color twitterBlue = Color(0xFF1DA1F2);
  static const Color linkedinBlue = Color(0xFF0A66C2);
  static const Color appleBlack = Color(0xFF000000);

  // ============================================
  // GRADIENTS
  // ============================================
  // Brand-derived gradients are `static final` rather than `const`
  // because [primary] / [secondary] are themselves runtime-initialised
  // (see the note above the brand-colour block).
  /// Full pink → lavender gradient — use for the app bar band and any
  /// surface that should mirror the hero gradient image.
  ///
  /// Direction comes from `currentBranding.headerGradientAngle` rather than
  /// fixed alignments, so re-angling the app bar is a one-line brand change
  /// and every surface mirroring the hero gradient turns with it.
  static final LinearGradient primaryGradient = LinearGradient(
    colors: [
      secondary, // 🩷 Hot pink — full opacity (gradient start)
      // 🟣 Indigo — faded light (gradient end). Header_Gradient_Dark holds it
      // at full strength instead.
      currentBranding.headerGradientDark
          ? primary
          : primary.withValues(alpha: 0.4),
    ],
    begin: currentBranding.headerGradientBegin,
    end: currentBranding.headerGradientEnd,
  );

  /// Convenience alias — same gradient, more descriptive name.
  static final LinearGradient appGradient = primaryGradient;

  static final LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [successLight, success],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [errorLight, error],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================
  // TRANSPARENT COLORS (with opacity)
  // ============================================
  static Color blackWithOpacity(double opacity) =>
      black.withValues(alpha: opacity);
  static Color whiteWithOpacity(double opacity) =>
      white.withValues(alpha: opacity);
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);
  static Color errorWithOpacity(double opacity) =>
      error.withValues(alpha: opacity);
  static Color successWithOpacity(double opacity) =>
      success.withValues(alpha: opacity);

  // ============================================
  // COMMON OVERLAY COLORS
  // ============================================
  static const Color overlayLight = Color(0x0A000000); // 4% opacity
  static const Color overlayMedium = Color(0x33000000); // 20% opacity
  static const Color overlayDark = Color(0x66000000); // 40% opacity

  // ============================================
  // SCAFFOLD BACKGROUNDS
  // ============================================
  /// Lavender-tinted white in light mode, `darkScaffold` in dark.
  /// The `Light`/`Dark` suffixes are kept for source compatibility —
  /// `scaffoldLight` now means "the scaffold colour for the active
  /// theme", and the explicit halves are [scaffoldLightFixed] /
  /// [scaffoldDarkFixed].
  static Color get scaffoldLight =>
      _pick(scaffoldLightFixed, currentBranding.darkScaffold);
  static Color get scaffoldDark => currentBranding.darkScaffold;

  static const Color scaffoldLightFixed = Color(0xFFFAF8FF);

  // ============================================
  // CARD COLORS
  // ============================================
  static Color get cardLight =>
      _pick(const Color(0xFFFFFFFF), currentBranding.darkSurface);
  static Color get cardDark => currentBranding.darkSurface;

  // ============================================
  // INPUT COLORS
  // ============================================
  static Color get inputFillLight =>
      _pick(const Color(0xFFF1F5F9), currentBranding.darkSurfaceElevated);
  static Color get inputFillDark => currentBranding.darkSurfaceElevated;
  static Color get inputBorderLight =>
      _pick(const Color(0xFFCBD5E1), currentBranding.darkDivider);
  static Color get inputBorderDark => const Color(0xFF475569);

  // ============================================
  // DIVIDER COLORS
  // ============================================
  static Color get dividerLight =>
      _pick(const Color(0xFFE2E8F0), currentBranding.darkDivider);
  static Color get dividerDark => currentBranding.darkDivider;

  // ============================================
  // SHADOW COLORS
  // ============================================
  static const Color shadowLight = Color(0x1F000000); // 12% opacity
  static const Color shadowMedium = Color(0x33000000); // 20% opacity
  static const Color shadowDark = Color(0x4D000000); // 30% opacity

  // ============================================
  // OTHER COLORS
  // ============================================
  static const Color transparent = Colors.transparent;
  static const Color ratingColor = Color(0xFFFF9933);
}
