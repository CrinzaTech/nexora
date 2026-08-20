import 'package:flutter/material.dart';

/// Brand-swappable configuration surface.
///
/// Aggregates the small set of constants that change per client
/// (colours, brand assets, display name) so onboarding a new client
/// boils down to:
///
///   1. Drop the client's logo / logo-with-text / login-background /
///      splash-background PNGs into `assets/images/` and
///      `assets/images/backgrounds/`.
///   2. Define a new `const BrandingConfig` for the client below.
///   3. Flip [currentBranding] to point at it.
///
/// Everything downstream — [AppColors], [AppImages], the theme, the
/// screens — reads through these centralised constants, so no screen
/// code needs to change to re-skin the app.
///
/// The class is intentionally `const`-only: the swap is a build-time
/// decision, the values flow into `static const` declarations in
/// AppColors / AppImages, and there's no runtime overhead.
class BrandingConfig {
  // ── Colours ────────────────────────────────────────────────────────

  /// Anchor brand colour — drives buttons, headers, accents.
  final Color primary;

  /// Lighter primary tone, used by primary gradients + soft surfaces.
  final Color primaryLight;

  /// Darker primary tone, used by pressed states + heavy backgrounds.
  final Color primaryDark;

  /// Accent brand colour — drives secondary affordances.
  final Color secondary;
  final Color secondaryLight;
  final Color secondaryDark;

  // ── Dark-mode surfaces ─────────────────────────────────────────────
  // The brand hues above are shared by both themes — only the neutral
  // canvas underneath them swaps. These are the dark half of every
  // dynamic token in [AppColors]; the light half stays where it was.
  //
  // All have defaults tuned for the indigo/pink palette, so an existing
  // BrandingConfig keeps compiling and only needs overrides when a
  // client's dark canvas should differ.

  /// Page backdrop behind everything — the dark twin of
  /// `AppColors.scaffoldLight`.
  final Color darkScaffold;

  /// Card / sheet / "white panel" surface — the dark twin of
  /// `AppColors.white`. This is the single most impactful value:
  /// every raised panel in the app resolves to it.
  final Color darkSurface;

  /// One step above [darkSurface] — chips, input fills, and anything
  /// that needs to read as raised *against* a card.
  final Color darkSurfaceElevated;

  /// Primary body/heading text on a dark canvas.
  final Color darkTextPrimary;

  /// De-emphasised body text on a dark canvas.
  final Color darkTextSecondary;

  /// Section labels and captions — the dark twin of
  /// `AppColors.mutedTextPrimary`.
  final Color darkTextMuted;

  /// Hairline separators on a dark canvas.
  final Color darkDivider;

  // ── Premium accent ─────────────────────────────────────────────────

  /// Warm metallic accent used for the thin top-edge highlight on cards
  /// and the soft outer glow behind raised surfaces.
  ///
  /// Deliberately never a fill: at full strength gold reads as cheap.
  /// It earns its "premium" feel by appearing only as a 1px lip catching
  /// the light and a wide, very low-alpha bloom — the way a real gilt
  /// edge behaves.
  final Color accent;

  /// Lighter tip of the accent, for the brightest point of a gradient
  /// hairline.
  final Color accentSoft;

  // ── Brand assets ───────────────────────────────────────────────────

  /// Square brand logo — splash, app-icon source, anywhere the brand
  /// glyph stands alone.
  final String logo;

  /// Horizontal brand lockup (glyph + wordmark) — login screen,
  /// verify-OTP screen header.
  final String logoWithText;

  /// Full-bleed splash backdrop displayed behind [logo] on the custom
  /// Flutter splash screen.
  final String splashBackground;

  /// Full-bleed login backdrop — login + verify-OTP screens.
  final String loginBackground;

  // ── Identity ───────────────────────────────────────────────────────

  /// User-facing app name — used in Razorpay merchant copy and any
  /// "Welcome to {appName}" surfaces. Bundle id / package id stays
  /// per-platform (android/app/build.gradle, ios/Runner/Info.plist).
  final String appName;
  final String packageName;

  // ── Tile Theme ────────────────────────────────────────────────────
  // These flags control the visual style of the home-page educator
  // category tiles. Moved here from .env so they are typed Dart
  // booleans with compile-time safety and IDE autocomplete.

  /// Fill tiles with a brand-colour gradient background.
  /// false → white neumorphic card (default).
  /// true  → coloured gradient card.
  final bool tileBgFill;

  /// Stretch each tile to span the full row width (1-column layout).
  /// false → default 2-column grid.
  final bool tileFullLength;

  /// Use the full saturated brand colours for tile gradients.
  /// false → pastel / 55 % lightened tones.
  final bool tileDark;

  // ── Tile Only-Icon Theme ─────────────────────────────────────────
  // The flags below are only meaningful when [tileBgFill] is false
  // (i.e. the white neumorphic card variant).

  /// Show only the tile icon — no text label alongside it.
  final bool tileOnlyIcon;

  /// Use a 3-column icon grid when [tileOnlyIcon] is true.
  /// false → 2-column grid.
  final bool tile3x3;

  /// Show the neumorphic shadow background behind the icon.
  /// false → icon fills the whole cell with no background.
  final bool tileBg;

  /// Draw the neumorphic background as a circle.
  /// false → rounded-square background.
  final bool tileOnlyBgCircular;

  /// Show the tile name below the icon when [tileOnlyIcon] is true.
  final bool tileText;

  const BrandingConfig({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryDark,
    // Dark-mode surfaces — defaulted so existing brands compile
    // unchanged and only override what they actually want to differ.
    this.darkScaffold = const Color(0xFF0A0F1C),
    this.darkSurface = const Color(0xFF131B2B),
    this.darkSurfaceElevated = const Color(0xFF1C2537),
    this.darkTextPrimary = const Color(0xFFEEF2F8),
    this.darkTextSecondary = const Color(0xFFC6D0DE),
    this.darkTextMuted = const Color(0xFF9AA7B8),
    this.darkDivider = const Color(0xFF26314A),
    this.accent = const Color(0xFFE3B857),
    this.accentSoft = const Color(0xFFF5D68A),
    required this.logo,
    required this.logoWithText,
    required this.splashBackground,
    required this.loginBackground,
    required this.appName,
    required this.packageName,
    // Tile theme
    this.tileBgFill = false,
    this.tileFullLength = false,
    this.tileDark = false,
    // Tile only-icon theme
    this.tileOnlyIcon = false,
    this.tile3x3 = false,
    this.tileBg = false,
    this.tileOnlyBgCircular = false,
    this.tileText = false,
  });
}

// ─────────────────────────────────────────────────────────────────────
// Brand registry — define one const per client and flip
// [currentBranding] to switch.
// ─────────────────────────────────────────────────────────────────────

/// Crinesta — default / production brand.
const crinestaBranding = BrandingConfig(
  // Indigo-purple primary brand palette
  primary: Color(0xFF0B1020),      // Indigo-purple — primary brand color, buttons, accents
  primaryLight: Color(0xFF252C42), // Soft indigo tint (hover / fill surfaces)
  primaryDark: Color(0xFF050812),  // Deep indigo — pressed / active states
  secondary: Color(0xFFFFC107),    // Hot pink — secondary accent color
  secondaryLight: Color(0xFFFFD54F), // Pale pink tint
  secondaryDark: Color(0xFFE6A800),  // Deep rose — pressed states
  // ── Dark-mode canvas ────────────────────────────────────────────
  // Deep ink-navy rather than flat slate. The wider gap between
  // scaffold and s
  // urface is what makes cards read as *raised* instead
  // of merely a different grey, and the low-saturation base keeps the
  // indigo/pink brand hues the brightest thing on screen.
  darkScaffold: Color(0xFF0A0F1C),        // Page backdrop — deep ink
  darkSurface: Color(0xFF131B2B),         // Cards / panels
  darkSurfaceElevated: Color(0xFF1C2537), // Chips / input fills
  // Text runs bright on purpose: the brief was "fully visible". These
  // stop short of pure white, which glares against a near-black page
  // and is what makes long reading sessions tiring.
  darkTextPrimary: Color(0xFFEEF2F8),     // Headings + body
  darkTextSecondary: Color(0xFFC6D0DE),   // De-emphasised body
  darkTextMuted: Color(0xFF9AA7B8),       // Section labels
  darkDivider: Color(0xFF26314A),         // Hairlines
  // ── Premium accent ───────────────────────────────────────────────
  accent: Color(0xFFE3B857),              // Gilt edge / glow
  accentSoft: Color(0xFFF5D68A),          // Highlight tip
  logo: 'assets/images/logo.png',
  logoWithText: 'assets/images/logo_with_text.png',
  splashBackground: 'assets/images/backgrounds/splash_background.png',
  loginBackground: 'assets/images/backgrounds/login_background.png',
  appName: 'NEXORA',
  packageName: 'com.nex.ora',
  // ── Tile Theme ──────────────────────────────────────────────────
  // Mirrors the values that were previously in .env.
  // Flip any flag here to change the tile visual style at build time.
  tileBgFill: true,
  tileFullLength: false,
  tileDark: true,
  // ── Tile Only-Icon Theme ─────────────────────────────────────────
  tileOnlyIcon: false,
  tile3x3: false,
  tileBg: false,
  tileOnlyBgCircular: false,
  tileText: false,
);

/// The active brand — what `AppColors` and `AppImages` read from.
///
/// To onboard a new client: add a new `BrandingConfig` constant above
/// (mirroring [crinestaBranding]'s shape), then change this single
/// line to point at it. Nothing else in the codebase needs to know.
const BrandingConfig currentBranding = crinestaBranding;
