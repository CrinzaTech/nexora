import 'dart:math' as math;

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

  // ── Gradient geometry ──────────────────────────────────────────────

  /// Angle of the brand gradient — the app-bar band and every surface that
  /// mirrors it — in degrees.
  ///
  ///     0   top → bottom      (default)
  ///    45   top-left → bottom-right
  ///    90   left → right
  ///   135   bottom-left → top-right
  ///   180   bottom → top
  ///   270   right → left
  ///
  /// Increases anticlockwise on screen. Values outside 0–360 wrap, so 450
  /// behaves as 90 and -90 as 270.
  final double headerGradientAngle;

  /// How strongly the brand gradient runs.
  ///
  /// false → the second stop fades to 40% alpha, so the band lightens as it
  ///         travels and the content over it stays easy to read.
  /// true  → both stops at full strength: a deeper, fully saturated band.
  ///
  /// The band carries white text and white-tinted icons, so this is a
  /// legibility decision as much as a stylistic one — the faded end is what
  /// keeps a light logo from getting lost at the pale corner, and the full
  /// one is what gives white content something solid to sit on.
  final bool headerGradientDark;

  /// Sweep a slow diagonal highlight across the app-bar band.
  ///
  /// The same glint the gradient tiles use, on the header. It only reads on a
  /// saturated surface, so it pairs with [headerGradientDark] — over the
  /// faded end of a light band a white streak has nothing to brighten.
  final bool headerShine;

  /// Start point for a gradient at [headerGradientAngle].
  Alignment get headerGradientBegin {
    final Offset d = _angleVector;
    return Alignment(-d.dx, -d.dy);
  }

  /// End point for a gradient at [headerGradientAngle].
  Alignment get headerGradientEnd {
    final Offset d = _angleVector;
    return Alignment(d.dx, d.dy);
  }

  /// Unit direction for [headerGradientAngle], stretched so the longer
  /// component reaches the edge of the box.
  ///
  /// Without that stretch a 45° angle yields (0.707, 0.707), which stops
  /// short of the corner — the gradient would visibly band before the edge
  /// instead of running the full diagonal. Scaling to ±1 makes the
  /// orthogonal angles edge-to-edge and the diagonals corner-to-corner,
  /// which is what "45°" is expected to look like.
  Offset get _angleVector {
    final double r = headerGradientAngle * math.pi / 180.0;
    final double dx = math.sin(r);
    final double dy = math.cos(r);
    // sin² + cos² == 1, so the larger magnitude is never below ~0.707 and
    // this cannot divide by zero.
    final double scale = 1.0 / math.max(dx.abs(), dy.abs());
    return Offset(dx * scale, dy * scale);
  }

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

  /// Whether the icon gets a neumorphic card behind it.
  /// false → icon fills the whole cell with nothing behind it.
  ///
  /// Applies to the neumorphic style only. [tileBgFill] is the equivalent
  /// switch for the gradient style and owns that decision by itself — with
  /// it on, the gradient card draws whatever this flag says, because two
  /// flags both meaning "does this tile have a background" only ever
  /// contradict each other.
  final bool tileBg;

  /// How heavy the [tileBg] neumorphic card sits.
  ///
  /// true  → deep and tight: a stronger depth tint thrown further from the
  ///         card over a shorter blur, so it reads as raised well off the
  ///         page.
  /// false → soft and airy: a fainter tint spread over a wider blur and
  ///         barely offset — the card whispers rather than announces.
  ///
  /// The mirror of [pngBgDark], and moves the same three things together
  /// (tint, blur, offset) for the same reason: depth lives in the ratio
  /// between blur and offset, not in opacity alone.
  ///
  /// Honoured by both card styles — it drives the neumorphic card's paired
  /// shadows and the gradient card's elevation. Needs [tileBg] for the
  /// former; the latter only needs [tileBgFill].
  final bool tileBgDark;

  /// Draw the icon's background as a circle.
  /// false → rounded-square background.
  ///
  /// Honoured by both card styles when [tileOnlyIcon] is true: it shapes the
  /// neumorphic card, and with [tileBgFill] on it shapes the gradient tile
  /// itself (squared off to the cell's shorter side, since a circle needs a
  /// square and the grid cell is not one).
  final bool tileOnlyBgCircular;

  /// Show the tile name alongside the icon when [tileOnlyIcon] is true.
  /// Placed below the card by default, or inside it when [tileBig] is on.
  final bool tileText;

  /// Blow the tile up to a square cell and move the label inside the card.
  ///
  /// The default icon layout sizes the artwork to a fixed footprint and hangs
  /// the label underneath it, on the page. [tileBig] instead makes every cell
  /// square, lets the card fill it edge to edge, and pins the label to the
  /// bottom *inside* the card — the artwork takes everything left over.
  ///
  /// Squareness is derived from the measured cell width rather than a design
  /// constant, so it holds at any column count and on any screen.
  ///
  /// Turns [tileOnlyIcon] on by itself — a big square tile stacks its icon
  /// over its label, which is that arrangement; the side-by-side layout puts
  /// them in a row and has nowhere to apply this. Honoured by both card
  /// styles.
  ///
  /// Composes with [tileText]: without a label the square cell simply hands
  /// the artwork more room.
  final bool tileBig;

  /// A [tileBig] tile whose label rides in a tinted banner across the top,
  /// with the artwork overlapping up into it.
  ///
  /// The banner is a rounded pill pinned to the top of the card, filled with
  /// that tile's own palette tone, and the artwork is painted *over* its
  /// lower edge — so the icon breaks the banner's outline instead of sitting
  /// politely beneath it. That overlap is the whole effect; without it this
  /// is just a label with a coloured box behind it.
  ///
  /// Turns on [tileBig] and [tileText] by itself. It is a treatment *of* the
  /// big tile's label, so neither is meaningful to leave off — with no label
  /// there is nothing to band, and with no square cell there is nowhere to
  /// band it.
  ///
  /// The banner always contrasts against its own card rather than the page:
  /// a coloured pill on the neutral neumorphic card, a near-white one on the
  /// [tileBgFill] gradient card.
  final bool tileTextBanner;

  /// Which half of a [tileTextBanner] tile carries the brand colour.
  ///
  /// false → coloured pill on a neutral card (the label is the accent).
  /// true  → neutral pill on a coloured card (the tile is the accent).
  ///
  /// Only ever one of the two: with both coloured the pill stops reading as
  /// a separate element, and with neither the tile has no accent at all. This
  /// flag just picks which one gets it.
  ///
  /// The pill's text follows its own backdrop, so contrast holds either way —
  /// white on the coloured pill, [AppColors.textPrimary] on the neutral one.
  ///
  /// Only meaningful when [tileTextBanner] is true.
  final bool tileBannerInvert;

  /// Corner shape of the [tileTextBanner] band.
  ///
  /// false → a full pill: the radius is half the band's height, so the ends
  ///         are semicircles.
  /// true  → the top two corners tighten to the card's own radius while the
  ///         bottom pair stays semicircular, so the band reads as tucked into
  ///         the top of the tile rather than laid over it.
  ///
  /// Only the top pair squares off. The bottom edge is the one the artwork
  /// breaks through, and squaring it would hand the icon a straight line to
  /// cross — the overlap stops reading as one shape passing behind another.
  ///
  /// Only meaningful when [tileTextBanner] is true.
  final bool tileBannerSquare;

  /// Cast the drop shadow from the PNG's own silhouette instead of from a
  /// box behind it.
  ///
  /// [tileBg] draws a neumorphic *card* — a rounded square (or circle) with
  /// its shadow tracing that shape, whatever the artwork inside looks like.
  /// [pngBg] instead reads the icon's alpha channel and casts the shadow
  /// from the artwork's actual outline, so a rounded-square icon throws a
  /// rounded-square shadow and a circular badge throws a circular one.
  ///
  /// Composes with [tileBg] rather than overriding it — the card is the
  /// surface the icon sits on, this shadow belongs to the icon itself, so
  /// either, both, or neither is a valid look. With [tileBg] off the icon
  /// floats on the page with only its own contour shadow.
  ///
  /// Only meaningful when [tileOnlyIcon] is true. Honoured by both the
  /// neumorphic and the [tileBgFill] gradient card.
  final bool pngBg;

  /// How heavy the [pngBg] contour shadow sits.
  ///
  /// true  → deep and tight: a stronger tint thrown a little further down
  ///         with less blur, so the icon reads as *resting on* the page.
  /// false → soft and airy: a fainter tint, wider blur, barely any offset,
  ///         so the icon reads as *floating just above* it.
  ///
  /// Moves tint, blur radius and offset together — a heavy tint that kept
  /// the light variant's diffuse blur just looks like grime under the icon
  /// rather than contact with a surface.
  ///
  /// The tint itself follows the theme rather than this flag: black in light
  /// mode, white in dark mode, where black would vanish against the canvas.
  /// This flag only picks how heavily that tint lands. Only meaningful when
  /// [pngBg] is true.
  final bool pngBgDark;

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
    this.headerGradientAngle = 0,
    this.headerGradientDark = false,
    this.headerShine = false,
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
    this.tileBgDark = false,
    this.tileOnlyBgCircular = false,
    this.tileText = false,
    this.tileBig = false,
    this.tileTextBanner = false,
    this.tileBannerInvert = false,
    this.tileBannerSquare = false,
    this.pngBg = false,
    this.pngBgDark = false,
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

  // ── Gradient geometry ───────────────────────────────────────────
  //  0°  begin (0, -1)   end (0,  1)    top → bottom
  //  45°  begin (-1,-1)   end (1,  1)    top-left → bottom-right
  //  90°  begin (-1, 0)   end (1,  0)    left → right
  //  135°  begin (-1, 1)   end (1, -1)    bottom-left → top-right
  //  180°  begin (0,  1)   end (0, -1)    bottom → top
  //  270°  begin (1,  0)   end (-1, 0)    right → left
  //  450°  begin (-1, 0)   end (1,  0)    wraps to 90°
  //  -90°  begin (1,  0)   end (-1, 0)    wraps to 270°

  headerGradientAngle: 0,
  headerGradientDark: false,
  headerShine: false,
  
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
  tileBgDark: false,
  tileOnlyBgCircular: false,
  tileText: false,

  tileBig: false,
  tileTextBanner: false,
  tileBannerInvert: false,
  tileBannerSquare: false,
  
  pngBg: false,
  pngBgDark: false,
);

/// The active brand — what `AppColors` and `AppImages` read from.
///
/// To onboard a new client: add a new `BrandingConfig` constant above
/// (mirroring [crinestaBranding]'s shape), then change this single
/// line to point at it. Nothing else in the codebase needs to know.
const BrandingConfig currentBranding = crinestaBranding;
