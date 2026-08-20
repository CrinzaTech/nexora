import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/branding_config.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tile palette helper — derives N premium gradients from the brand config.
//
// Strategy: we build 6 gradient "slots" from the BrandingConfig's 6 tones
// (primary, primaryLight, primaryDark, secondary, secondaryLight,
// secondaryDark). Each slot is a diagonal two-stop gradient that looks rich
// but stays on-brand. The list is cycled round-robin so every tile index gets
// a deterministic, unique-within-a-screen look without any randomness at
// build time (which would cause rebuild flicker).
// ─────────────────────────────────────────────────────────────────────────────
class _TilePalette {
  _TilePalette._();

  /// Returns a brand-derived [LinearGradient] for [index].
  /// When [isDark] is true the full saturated brand colours are used.
  /// When [isDark] is false every colour is blended ~55 % toward white,
  /// giving a soft pastel wash that reads as 50–60 % lighter.
  static LinearGradient gradientAt(int index, {required bool isDark}) {
    final b = currentBranding;

    /// Each entry is [stop0, stop1] — going top-left → bottom-right.
    final pairs = <List<Color>>[
      // 1. Deep indigo → vibrant indigo
      [b.primaryDark, b.primary],
      // 2. Royal blue → bright indigo
      [b.secondary, b.primaryLight],
      // 3. Bright indigo → royal blue
      [b.primaryLight, b.secondary],
      // 4. Deep indigo → royal blue
      [b.primaryDark, b.secondary],
      // 5. Primary → secondary dark (slate blue)
      [b.primary, b.secondaryDark],
      // 6. Secondary → primary dark (deep)
      [b.secondary, b.primaryDark],
    ];

    final rawColors = pairs[index % pairs.length];

    // Lighten each stop by blending it 55 % toward white when not dark mode.
    Color resolve(Color c) => isDark ? c : Color.lerp(c, AppColors.white, 0.55)!;

    return LinearGradient(
      colors: [
        resolve(rawColors[0]),
        resolve(rawColors[1]).withValues(alpha: 0.85),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Shimmer/shine overlay gradient — always white, just varies direction.
  static LinearGradient shineAt(int index) {
    final begins = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment.topCenter,
      Alignment.centerLeft,
    ];
    return LinearGradient(
      colors: [
        AppColors.alwaysWhite.withValues(alpha: 0.18),
        AppColors.alwaysWhite.withValues(alpha: 0.00),
      ],
      begin: begins[index % begins.length],
      end: Alignment.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class CategorySection extends StatelessWidget {
  final List<EducatorTile> tiles;

  const CategorySection({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final rh = ResponsiveHelper.of(context);

    // ── Tile_Full_Length flag ─────────────────────────────────────────────────
    // When true every tile spans the full available width (1 column).
    // When false the default 2-column grid is used.
    final isFull = currentBranding.tileFullLength;

    // ── Tile_Only_Icon flag ───────────────────────────────────────────────────
    // When true: 3-column icon grid with a shorter tile height (no text row).
    // When false: the crossAxisCount / height is governed by Tile_Full_Length.
    final iconOnly = currentBranding.tileOnlyIcon;

    // ── Tile_Text flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → show the tile name below the neumorphic image background.
    // false → icon only, no text at all.
    final showText = currentBranding.tileText;

    // ── Tile_3_X_3 flag ──────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → 3 icons per row.
    // false → 2 icons per row.
    final is3x3 = currentBranding.tile3x3;

    // How many icon columns to display (3 or 2).
    final int colCount = is3x3 ? 3 : 2;

    // Priority: iconOnly > isFull > default-2-col.
    final int crossAxisCount = iconOnly ? colCount : (isFull ? 1 : 2);

    // Icon-only tile height depends on column count and whether text is shown.
    //   3-col: imgSize=64   → containerSize=82   → 90dp cell is fine.
    //   2-col: imgSize=130  → containerSize=134  → needs 160dp (no text)
    //                                            or 195dp (with text below).
    final double tileHeight = iconOnly
        ? (is3x3
              ? (showText
                    ? Screen.getVerticalSize(116).clamp(
                        0.0,
                        rh.isLargeScreen ? 160.0 : 130.0,
                      ) // 3-col + text
                    : Screen.getVerticalSize(
                        90,
                      ).clamp(0.0, rh.isLargeScreen ? 130.0 : 100.0)) // 3-col, no text
              : (showText
                    ? Screen.getVerticalSize(165).clamp(
                        0.0,
                        rh.isLargeScreen ? 220.0 : 185.0,
                      ) // 2-col + text
                    : Screen.getVerticalSize(
                        160,
                      ).clamp(0.0, rh.isLargeScreen ? 210.0 : 180.0))) // 2-col, no text
        : isFull
        ? Screen.getVerticalSize(80).clamp(0.0, rh.isLargeScreen ? 120.0 : 96.0)
        : Screen.getVerticalSize(88).clamp(0.0, rh.isLargeScreen ? 130.0 : 100.0);

    // Tighter horizontal spacing for the icon grid.
    final double crossAxisSpacing = iconOnly ? 10 : 15;

    return Padding(
      padding: isFull
          ? Screen.getPadding(left: 20, right: 20, top: 20, bottom: 20)
          : Screen.getPadding(left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Featured Categories",
                style: AppTypography.h5SemiBold.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSizeCapped(20),
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.catalog),
                child: Text(
                  "View All",
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.primary,
                    fontSize: Screen.getFontSizeCapped(14),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: Screen.getVerticalSize(10)),

          // ── Icon-only grid: manual rows so the last partial row centres ──────
          if (iconOnly) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                // Chunk tiles into rows of colCount (3 or 2).
                final rows = <List<EducatorTile>>[];
                for (var i = 0; i < tiles.length; i += colCount) {
                  rows.add(
                    tiles.sublist(i, (i + colCount).clamp(0, tiles.length)),
                  );
                }

                // Number of gaps in a full row = colCount - 1.
                final int gapCount = colCount - 1;

                // Cell width: divide available space equally across colCount cols.
                final double cellWidth =
                    (constraints.maxWidth -
                        crossAxisSpacing * gapCount) // gaps between cols
                    /
                    colCount;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var ri = 0; ri < rows.length; ri++) ...[
                      Row(
                        // Full rows → spread evenly; partial last row → centre.
                        mainAxisAlignment: rows[ri].length == colCount
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.center,
                        children: [
                          for (var ci = 0; ci < rows[ri].length; ci++) ...[
                            // Add gap between tiles for partial rows only
                            // (full rows use spaceBetween which handles gaps).
                            if (ci > 0 && rows[ri].length < colCount)
                              SizedBox(width: crossAxisSpacing),
                            SizedBox(
                              height: tileHeight,
                              width: cellWidth,
                              child: _CategoryCard(
                                tile: rows[ri][ci],
                                index: ri * colCount + ci,
                                isFull: isFull,
                                onTap: () => context.push(
                                  '${AppRoutes.catalog}?tileId=${rows[ri][ci].tileId}&title=${Uri.encodeComponent(rows[ri][ci].tileName)}',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (ri < rows.length - 1)
                        SizedBox(height: Screen.getVerticalSize(10)),
                    ],
                  ],
                );
              },
            ),
          ] else ...[
            // ── Normal 2-col or full-length grid ───────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              itemCount: tiles.length,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisExtent: tileHeight,
              ),
              itemBuilder: (context, index) {
                final tile = tiles[index];
                return _CategoryCard(
                  tile: tile,
                  index: index,
                  isFull: isFull,
                  onTap: () => context.push(
                    '${AppRoutes.catalog}?tileId=${tile.tileId}&title=${Uri.encodeComponent(tile.tileName)}',
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final EducatorTile tile;
  final int index;
  final bool isFull;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.tile,
    required this.index,
    required this.isFull,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = currentBranding.tileBgFill;

    // ── Tile_Dark flag ──────────────────────────────────────────────────────
    // true  → full saturated brand-colour gradient (original look).
    // false → colours blended ~55 % toward white (50–60 % lighter, pastel).
    final isDark = currentBranding.tileDark;

    // ── Tile_Only_Icon flag ─────────────────────────────────────────────────
    // true  → show only the tile image (no text label), image is enlarged and
    //         centred so the extra space is properly used.
    // false → default layout: image + text side by side.
    final iconOnly = currentBranding.tileOnlyIcon;

    // ── Tile_Only_Bg_Cricular flag ───────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → neumorphic background is a circle.
    // false → neumorphic background is a rounded square.
    final isCircular = currentBranding.tileOnlyBgCircular;

    // ── Tile_Text flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → show the tile name below the neumorphic image background.
    // false → icon only, no text at all.
    final showText = currentBranding.tileText;

    // ── Tile_3_X_3 flag ──────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → 3 icons per row (smaller cells).
    // false → 2 icons per row (larger cells → image should be bigger).
    final is3x3 = currentBranding.tile3x3;

    // ── Tile_Bg flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → show the neumorphic background.
    // false → remove background, image grows to fill the entire bg size.
    final showBg = currentBranding.tileBg;

    return isFilled
        ? _FilledCard(
            tile: tile,
            index: index,
            isFull: isFull,
            isDark: isDark,
            iconOnly: iconOnly,
            onTap: onTap,
          )
        : _DefaultCard(
            tile: tile,
            isFull: isFull,
            iconOnly: iconOnly,
            isCircular: isCircular,
            showText: showText,
            is3x3: is3x3,
            showBg: showBg,
            onTap: onTap,
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT CARD — original white neumorphic style (Tile_BG_FILL != true)
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultCard extends StatelessWidget {
  final EducatorTile tile;
  final bool isFull;
  final bool iconOnly;
  final bool isCircular;
  final bool showText;
  final bool is3x3;
  final bool showBg;
  final VoidCallback? onTap;

  const _DefaultCard({
    required this.tile,
    required this.isFull,
    required this.iconOnly,
    this.isCircular = false,
    this.showText = false,
    this.is3x3 = true,
    this.showBg = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final radius = BorderRadius.circular(AppSizes.radiusM);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.primary.withValues(alpha: 0.47);
    final innerColor = AppColors.primary.withValues(alpha: 0.12);

    // ── Image dimensions ────────────────────────────────────────────────────
    // iconOnly 3-col (is3x3=true) : 64dp — compact cells, smaller image.
    // iconOnly 2-col (is3x3=false): 130dp — wider cells, much larger image.
    // normal layout               : original side-by-side sizing.
    final double imgSize = iconOnly
        ? Screen.getSize(
            isFull ? 88 : (is3x3 ? 64 : 130),
          ).clamp(0.0, rh.isLargeScreen ? (isFull ? 140.0 : (is3x3 ? 110.0 : 180.0)) : (isFull ? 100.0 : (is3x3 ? 75.0 : 145.0)))
        : Screen.getSize(isFull ? 68 : 52).clamp(0.0, rh.isLargeScreen ? (isFull ? 100.0 : 80.0) : (isFull ? 80.0 : 60.0));

    // ── Icon-only: neumorphic background (circle or rounded square) ───────────
    if (iconOnly) {
      // Neumorphism uses a mid-tone background with two opposing shadows:
      //   • top-left bright shadow  → gives the "raised light source" highlight
      //   • bottom-right dark shadow → gives the depth / elevation shadow
      // Page-tone surface the raised icon sits on.
      final nmBg = AppColors.grey100;
      // The 'light source' highlight. On a dark surface a near-opaque
      // white reads as a blown-out patch rather than a soft edge, so
      // dark mode uses a much fainter sheen.
      final nmLight = AppColors.alwaysWhite.withValues(
        alpha: AppColors.isDark ? 0.06 : 0.85,
      );
      final nmDark = AppColors.primary.withValues(alpha: 0.22);

      // Calculate padding based on whether we are showing the background.
      final double defaultPadding = is3x3 ? 10 : 2;
      final double paddingVal = showBg ? defaultPadding : 0;

      // If we hide the background, we grow the image by the amount of padding
      // removed so the container footprint stays exactly the same.
      final double finalImgSize = showBg
          ? imgSize
          : imgSize + Screen.getSize(defaultPadding * 2);

      final double containerSize =
          finalImgSize + Screen.getSize(paddingVal * 2);

      // The neumorphic shape widget — shared between icon-only and
      // icon+text layouts.
      final Widget nmContainer = Container(
        height: containerSize,
        width: containerSize,
        decoration: showBg
            ? BoxDecoration(
                color: nmBg,
                // ── Shape driven by Tile_Only_Bg_Cricular flag ─────────────
                shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircular
                    ? null
                    : BorderRadius.circular(AppSizes.radiusM),
                boxShadow: [
                  // ── Highlight (top-left) ──────────────────────────────────────────
                  BoxShadow(
                    color: nmLight,
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(-5, -5),
                  ),
                  // ── Depth shadow (bottom-right) ───────────────────────────────
                  BoxShadow(
                    color: nmDark,
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(5, 5),
                  ),
                ],
              )
            : null,
        padding: EdgeInsets.all(Screen.getSize(paddingVal)),
        child: CustomNetworkImage(
          url: tile.tileLogoURL,
          fit: BoxFit.contain,
          errorWidget: Image.asset(AppImages.bookImg),
        ),
      );

      return GestureDetector(
        onTap: onTap,
        child: Center(
          child: showText
              // ── Icon + label: neumorphic bg on top, text below it ────────────
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nmContainer,
                    SizedBox(height: Screen.getVerticalSize(6)),
                    Text(
                      tile.tileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.primary,
                        fontSize: rh.isLargeScreen ? rh.cappedFontSize(20) : Screen.getFontSizeCapped(18),
                      ),
                    ),
                  ],
                )
              // ── Icon only: just the neumorphic container ─────────────────────
              : nmContainer,
        ),
      );
    }

    // ── Normal: original white card with gradient border ─────────────────────
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.10),
            blurRadius: 9,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card surface — solid white + gradient border.
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: radius,
              border: GradientBorder(
                gradient: LinearGradient(
                  colors: [borderLow, borderMid, borderLow],
                ),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                splashColor: AppColors.primary.withValues(alpha: 0.10),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: Center(
                  child: Padding(
                    padding: isFull
                        ? Screen.getPadding(all: 8)
                        : Screen.getPadding(horizontal: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: imgSize,
                          width: imgSize,
                          child: CustomNetworkImage(
                            url: tile.tileLogoURL,
                            fit: BoxFit.contain,
                            errorWidget: Image.asset(AppImages.bookImg),
                          ),
                        ),
                        SizedBox(width: Screen.getHorizontalSize(10)),
                        Expanded(
                          child: Text(
                            tile.tileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: AppColors.primary,
                              fontSize: rh.isLargeScreen
                                  ? rh.cappedFontSize(isFull ? 18 : 16)
                                  : Screen.getFontSizeCapped(isFull ? 16 : 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Inner shadow overlay — Figma: (0, 4), blur 54, #6C63FF@12%.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: InnerShadowPainter(
                  color: innerColor,
                  blurRadius: 54,
                  offset: const Offset(0, 4),
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILLED CARD — dynamic brand-color gradient style (Tile_BG_FILL=true)
//
// Each tile gets a unique gradient from the brand palette, an animated
// diagonal shine sweep, a coloured drop-shadow that echoes the gradient,
// and white text — all composed to feel premium and classy.
// ─────────────────────────────────────────────────────────────────────────────

class _FilledCard extends StatefulWidget {
  final EducatorTile tile;
  final int index;
  final bool isFull;
  final bool isDark;
  final bool iconOnly;
  final VoidCallback? onTap;

  const _FilledCard({
    required this.tile,
    required this.index,
    required this.isFull,
    required this.isDark,
    required this.iconOnly,
    this.onTap,
  });

  @override
  State<_FilledCard> createState() => _FilledCardState();
}

class _FilledCardState extends State<_FilledCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineCtrl;
  late final Animation<double> _shineAnim;

  @override
  void initState() {
    super.initState();
    // Each tile starts its sweep at a different point so they don't all
    // flash in sync — offset by index * 0.3s, clamped to [0, period).
    const period = Duration(milliseconds: 2800);
    const pauseBetween = Duration(milliseconds: 1600);

    _shineCtrl = AnimationController(vsync: this, duration: period);

    // Ease-in-out so the streak accelerates in and fades out naturally.
    _shineAnim = CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut);

    // Stagger tiles so they don't sweep simultaneously.
    Future.delayed(Duration(milliseconds: widget.index * 320), () {
      if (!mounted) return;
      _runLoop(pauseBetween);
    });
  }

  void _runLoop(Duration pause) async {
    while (mounted) {
      await _shineCtrl.forward(from: 0);
      await Future.delayed(pause);
    }
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final isDark = widget.isDark;
    final radius = BorderRadius.circular(AppSizes.radiusM);
    final gradient = _TilePalette.gradientAt(widget.index, isDark: isDark);
    final staticShine = _TilePalette.shineAt(widget.index);

    // Shadow: vivid and coloured in dark mode; soft and muted in light mode.
    final shadowColor = isDark
        ? gradient.colors.first.withValues(alpha: 0.45)
        : gradient.colors.first.withValues(alpha: 0.22);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Coloured ambient shadow — signature of premium cards.
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          // Soft black shadow for depth separation.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // ── Base gradient fill ──────────────────────────────────────
            Positioned.fill(
              child: Container(decoration: BoxDecoration(gradient: gradient)),
            ),

            // ── Static gloss overlay ────────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(gradient: staticShine),
                ),
              ),
            ),

            // ── Animated shine sweep ────────────────────────────────────
            // A narrow white streak that slides diagonally from the
            // top-left corner to the bottom-right corner on each pass.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shineAnim,
                  builder: (_, __) {
                    final t = _shineAnim.value;
                    // Map [0,1] → streak centre travels from -0.6 to 1.6
                    // (just off screen on both ends) so the entry/exit is
                    // always clean with no hard edges visible.
                    final center = -0.6 + t * 2.2;
                    const halfWidth = 0.18; // streak width as fraction

                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [
                            (center - halfWidth).clamp(0.0, 1.0),
                            center.clamp(0.0, 1.0),
                            (center + halfWidth).clamp(0.0, 1.0),
                          ],
                          colors: [
                            AppColors.alwaysWhite.withValues(alpha: 0.0),
                            AppColors.alwaysWhite.withValues(alpha: 0.28),
                            AppColors.alwaysWhite.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Subtle inner highlight at top edge ─────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: Container(color: AppColors.alwaysWhite.withValues(alpha: 0.30)),
              ),
            ),

            // ── Tap ripple + content ────────────────────────────────────
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: radius,
                  splashColor: AppColors.alwaysWhite.withValues(alpha: 0.12),
                  highlightColor: AppColors.alwaysWhite.withValues(alpha: 0.06),
                  child: Center(
                    child: widget.iconOnly
                        // ── Icon-only layout: centred, enlarged image ─────
                        ? SizedBox(
                            height: Screen.getSize(
                              widget.isFull ? 80 : 64,
                            ).clamp(0.0, rh.isLargeScreen ? 120.0 : (widget.isFull ? 90.0 : 75.0)),
                            width: Screen.getSize(
                              widget.isFull ? 80 : 64,
                            ).clamp(0.0, rh.isLargeScreen ? 120.0 : (widget.isFull ? 90.0 : 75.0)),
                            child: CustomNetworkImage(
                              url: widget.tile.tileLogoURL,
                              fit: BoxFit.contain,
                              errorWidget: ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  -1,
                                  0,
                                  0,
                                  0,
                                  255,
                                  0,
                                  -1,
                                  0,
                                  0,
                                  255,
                                  0,
                                  0,
                                  -1,
                                  0,
                                  255,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                                child: Image.asset(AppImages.bookImg),
                              ),
                            ),
                          )
                        // ── Normal layout: image + text side by side ──────
                        : Padding(
                            padding: widget.isFull
                                ? Screen.getPadding(all: 8)
                                : Screen.getPadding(horizontal: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Icon — no background container, image fills
                                // the SizedBox directly for maximum visible size.
                                SizedBox(
                                  height: Screen.getVerticalSize(
                                    widget.isFull ? 68 : 52,
                                  ).clamp(0.0, rh.isLargeScreen ? 90.0 : 999.0),
                                  width: Screen.getHorizontalSize(
                                    widget.isFull ? 68 : 52,
                                  ).clamp(0.0, rh.isLargeScreen ? 90.0 : 999.0),
                                  child: CustomNetworkImage(
                                    url: widget.tile.tileLogoURL,
                                    fit: BoxFit.contain,
                                    errorWidget: ColorFiltered(
                                      colorFilter: const ColorFilter.matrix([
                                        -1,
                                        0,
                                        0,
                                        0,
                                        255,
                                        0,
                                        -1,
                                        0,
                                        0,
                                        255,
                                        0,
                                        0,
                                        -1,
                                        0,
                                        255,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ]),
                                      child: Image.asset(AppImages.bookImg),
                                    ),
                                  ),
                                ),
                                SizedBox(width: Screen.getHorizontalSize(10)),
                                Expanded(
                                  child: Text(
                                    widget.tile.tileName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyTextLargeSemiBold
                                        .copyWith(
                                          // Dark gradient → white text with shadow.
                                          // Light gradient → dark text, no shadow.
                                          color: isDark
                                              ? AppColors.alwaysWhite
                                              : AppColors.textPrimary,
                                          fontSize: rh.isLargeScreen
                                              ? rh.cappedFontSize(widget.isFull ? 18 : 16)
                                              : Screen.getFontSizeCapped(
                                                  widget.isFull ? 16 : 13,
                                                ),
                                          shadows: isDark
                                              ? [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
