import 'dart:ui' show ImageFilter;

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
    Color resolve(Color c) =>
        isDark ? c : Color.lerp(c, AppColors.white, 0.55)!;

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
// Icon-tile metrics — single source of truth for the Tile_Only_Icon layout.
//
// The grid cell and the card that fills it have to agree on how tall the
// content is, and they used to be derived independently: the cell came from
// hard-coded design constants scaled through Screen.getVerticalSize() with one
// clamp, while the image inside it scaled through Screen.getSize() with a
// different clamp, and the Tile_Text label added a line box nobody budgeted
// for. Those curves cross on real devices, so Tile_Only_Icon + Tile_Text
// overflowed the Column by a few pixels on every screen size — including the
// 360x812 design baseline it was tuned on. Deriving the cell from these
// numbers keeps the two locked together everywhere.
// ─────────────────────────────────────────────────────────────────────────────
class _IconTileMetrics {
  /// Side of the square neumorphic container — the icon's full footprint.
  /// Identical whether or not the background is drawn: with Tile_Bg off the
  /// padding collapses and the image grows by exactly what was removed.
  final double containerSize;

  /// Inset between the container edge and the image, when Tile_Bg is on.
  final double padding;

  /// Vertical gap between the icon and its label.
  final double gap;

  /// Font size of the single-line label.
  final double fontSize;

  const _IconTileMetrics({
    required this.containerSize,
    required this.padding,
    required this.gap,
    required this.fontSize,
  });

  /// The line-height multiplier baked into
  /// [AppTypography.bodyTextLargeSemiBold]. The card's copyWith() only
  /// overrides fontSize, so the label's line box stays fontSize * this —
  /// which is the row of pixels the old constants never accounted for.
  static const double _labelLineHeight = 24 / 16;

  /// Height of the single label line, rounded up. A fractional line box is
  /// exactly what surfaced as "overflowed by 3.7 pixels".
  double get labelHeight => lineBoxFor(fontSize);

  /// Line box for an arbitrary size, using the same multiplier. Lets a caller
  /// run a different font size without re-deriving how tall its line is.
  double lineBoxFor(double size) => (size * _labelLineHeight).ceilToDouble();

  /// The height the card actually paints, and therefore the height the grid
  /// cell must reserve.
  double cellHeight({required bool showText}) =>
      showText ? containerSize + gap + labelHeight : containerSize;

  factory _IconTileMetrics.resolve({
    required ResponsiveHelper rh,
    required bool isFull,
    required bool is3x3,
  }) {
    // Image dimensions:
    //   3-col (is3x3=true)  : 64dp  — compact cells, smaller image.
    //   2-col (is3x3=false) : 130dp — wider cells, much larger image.
    //   full-length         : 88dp.
    final double imageSize = Screen.getSize(isFull ? 88 : (is3x3 ? 64 : 130))
        .clamp(
          0.0,
          rh.isLargeScreen
              ? (isFull ? 140.0 : (is3x3 ? 110.0 : 180.0))
              : (isFull ? 100.0 : (is3x3 ? 75.0 : 145.0)),
        );

    final double padding = Screen.getSize(is3x3 ? 10 : 2);

    return _IconTileMetrics(
      containerSize: imageSize + padding * 2,
      padding: padding,
      gap: Screen.getVerticalSize(6),
      fontSize: rh.isLargeScreen
          ? rh.cappedFontSize(20)
          : Screen.getFontSizeCapped(18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contour drop shadow — the Png_Bg tile theme.
//
// A BoxShadow can only trace the *box*: turn it on behind a rounded-square
// icon and you get a rounded-square shadow, behind a circular badge a
// circular one, regardless of what the artwork actually is. This instead
// reads the PNG's alpha channel, so the shadow is cast by the icon's own
// outline — a cut-out stethoscope throws a stethoscope-shaped shadow.
//
// The artwork is painted twice: once flattened to a single tint and blurred
// (the shadow), then again untouched on top.
// ─────────────────────────────────────────────────────────────────────────────
class _ContourShadow extends StatelessWidget {
  final Widget child;

  /// Fully resolved tint, alpha included. Left to the call site because it
  /// depends on what the icon sits *on*: the page canvas under a neumorphic
  /// tile, a brand gradient under a filled one.
  final Color color;

  /// The icon's rendered extent in dp. Blur and offset scale off this so a
  /// 3-col tile never wears a 2-col tile's shadow.
  final double extent;

  /// Deep and tight (true) versus soft and airy (false).
  final bool deep;

  const _ContourShadow({
    required this.child,
    required this.color,
    required this.extent,
    required this.deep,
  });

  // Depth is carried by the ratio between blur and offset, not by opacity:
  // a contact shadow is tight and thrown further, an airy one is wide and
  // barely displaced. Turning up only the alpha on a diffuse blur reads as
  // grime under the icon rather than as weight — so [deep] moves both.
  //
  // Both stay conservative. The blur bleeds past the tile into the 10dp
  // gutter, which is what sells "raised off the page", but a bigger offset
  // would smear into the label underneath.
  //
  // Both are floored. Pure proportional scaling was tuned against a 150dp
  // icon-only tile; at the 52dp of a side-by-side one it lands on a 2px blur
  // offset by 1.8px, which is not a faint shadow but no shadow at all. A
  // shadow needs a few absolute pixels before the eye reads it as depth,
  // regardless of how big the thing casting it is.
  static const double _minBlur = 4.5;
  static const double _minOffset = 2.5;

  double get _blur {
    final double scaled = extent * (deep ? 0.040 : 0.058);
    return scaled < _minBlur ? _minBlur : scaled;
  }

  Offset get _offset {
    final double scaled = extent * (deep ? 0.034 : 0.020);
    return Offset(0, scaled < _minOffset ? _minOffset : scaled);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Stack clips to its bounds by default, which would shave the blur off
      // at the icon's edge and leave a hard rectangular cut — the exact
      // artefact this widget exists to avoid.
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Transform.translate(
          offset: _offset,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
            // srcIn keeps the artwork's alpha and replaces every colour with
            // the tint — a true silhouette. A plain opacity would instead
            // give a washed-out copy of the icon, colours and all.
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: child,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner layout — the Tile_Text_Banner treatment.
//
// The label rides in a tinted pill across the top of the card and the artwork
// is painted over the pill's lower edge, breaking its outline. Stacking order
// is the entire effect: banner first, artwork second. Reverse them and this
// collapses into a label with a coloured box behind it.
// ─────────────────────────────────────────────────────────────────────────────
class _BannerTile extends StatefulWidget {
  final Widget artwork;
  final String label;

  /// The pill's fill. Exactly one of these is set, and it is the opposite of
  /// whatever the card behind the artwork uses — only one of the two can be
  /// the coloured half or the pill stops reading as a separate element.
  /// Tile_Banner_Invert picks which.
  final Gradient? bannerGradient;
  final Color? bannerColor;
  final Color textColor;
  final _IconTileMetrics metrics;

  /// Squared off to the card's own radius rather than run as a full pill.
  final bool squared;

  /// Staggers this tile's shine so a row doesn't flash in unison.
  final int index;

  const _BannerTile({
    required this.artwork,
    required this.label,
    required this.textColor,
    required this.metrics,
    required this.index,
    this.bannerGradient,
    this.bannerColor,
    this.squared = false,
  });

  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile>
    with SingleTickerProviderStateMixin {
  /// How far down the banner the artwork starts, as a fraction of the
  /// banner's height. Below ~0.5 the icon swallows the text; above ~0.8 the
  /// two stop touching and the overlap reads as a mistake rather than a
  /// composition.
  static const double _overlap = 0.62;

  /// The banner runs smaller than the standard tile label. It sits on its own
  /// coloured field rather than in open space, so it reads a size larger than
  /// it measures.
  static const double _fontScale = 0.85;

  /// Leading inside the pill.
  ///
  /// Now that [_heightFraction] fixes the band's height, this no longer sizes
  /// anything — it only decides how the two lines are distributed inside a
  /// band that is already there. That makes it a straight typographic call
  /// rather than a trade against the tile's proportions, so it runs loose:
  /// two short stacked words want air between them, and there is spare room
  /// in the band to give.
  static const double _lineHeight = 1.45;

  /// Banner height as a share of the tile.
  ///
  /// Deliberately a fraction of the tile rather than a function of the label:
  /// sized off its text, each banner came out as tall as its own category
  /// name happened to be, so a row of them stepped up and down. A fixed share
  /// gives every tile the same band and lets the text sit centred in it.
  static const double _heightFraction = 0.45;

  late final AnimationController _shineCtrl;
  late final Animation<double> _shineAnim;

  /// The streak only reads on the coloured half. With Tile_Banner_Invert the
  /// pill is the neutral one and the card behind it carries the colour, so
  /// the sweep belongs to the card and _FilledCard runs it instead.
  bool get _shines => widget.bannerGradient != null;

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _shineAnim = CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut);

    if (!_shines) return;
    Future.delayed(Duration(milliseconds: widget.index * 320), () {
      if (!mounted) return;
      _runLoop();
    });
  }

  void _runLoop() async {
    while (mounted) {
      await _shineCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1600));
    }
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _build(constraints),
    );
  }

  Widget _build(BoxConstraints constraints) {
    final double inset = Screen.getSize(6);
    final double padV = Screen.getSize(2);
    final double fontSize = widget.metrics.fontSize * _fontScale;
    final double lineBox = (fontSize * _lineHeight).ceilToDouble();

    // Two lines' worth: category names are usually two words, and a banner
    // that reflowed between one and two lines per tile would leave the row
    // looking ragged.
    final double textHeight = lineBox * 2 + padV * 2;

    // Floored at what the text actually needs. On a small 3-column tile the
    // share lands under two lines, and the band has a fixed height — the
    // label would be clipped rather than the band shrinking with it.
    final double share = constraints.hasBoundedHeight
        ? constraints.maxHeight * _heightFraction
        : textHeight;
    final double bannerHeight = share < textHeight ? textHeight : share;

    // Half the height is what makes the ends semicircular.
    //
    // Squared, only the *top* pair tightens to the card's own radius: those
    // are the corners sitting up against the tile's own, and matching them is
    // what makes the band read as tucked into the top rather than laid over
    // it. The bottom pair stays semicircular, because that is the edge the
    // artwork breaks through — squaring it too would give the icon a straight
    // line to cross and lose the overlap.
    final Radius round = Radius.circular(bannerHeight / 2);
    final BorderRadius pillRadius = widget.squared
        ? BorderRadius.only(
            topLeft: const Radius.circular(AppSizes.radiusM),
            topRight: const Radius.circular(AppSizes.radiusM),
            bottomLeft: round,
            bottomRight: round,
          )
        : BorderRadius.all(round);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: inset,
          left: inset,
          right: inset,
          height: bannerHeight,
          child: Container(
            decoration: BoxDecoration(
              color: widget.bannerColor,
              gradient: widget.bannerGradient,
              borderRadius: pillRadius,
            ),
            // Clipped so the streak stops at the pill's edge instead of
            // running square across its rounded ends.
            child: ClipRRect(
              borderRadius: pillRadius,
              child: Stack(
                children: [
                  if (_shines)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shineAnim,
                          builder: (_, __) => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _streak(_shineAnim.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Screen.getSize(10),
                        vertical: padV,
                      ),
                      child: Center(
                        child: Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            color: widget.textColor,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            height: _lineHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: inset + bannerHeight * _overlap,
          left: inset,
          right: inset,
          bottom: inset,
          child: widget.artwork,
        ),
      ],
    );
  }

  /// A narrow white streak travelling corner to corner. Mapped so its centre
  /// starts and ends off the pill, which is what keeps the entry and exit
  /// clean instead of popping in at full strength.
  LinearGradient _streak(double t) {
    final double centre = -0.6 + t * 2.2;
    const double halfWidth = 0.18;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [
        (centre - halfWidth).clamp(0.0, 1.0),
        centre.clamp(0.0, 1.0),
        (centre + halfWidth).clamp(0.0, 1.0),
      ],
      colors: [
        AppColors.alwaysWhite.withValues(alpha: 0.0),
        AppColors.alwaysWhite.withValues(alpha: 0.28),
        AppColors.alwaysWhite.withValues(alpha: 0.0),
      ],
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
    // When true: icon grid, crossAxisCount from Tile_3_X_3.
    // When false: the crossAxisCount / height is governed by Tile_Full_Length.
    //
    // Tile_Big implies it. A big square tile stacks its icon over its label,
    // which *is* the icon-only arrangement — the side-by-side one puts them
    // in a row and has nowhere to apply it. Requiring both flags would just
    // make Tile_Big silently do nothing on its own.
    // Tile_Text_Banner is a treatment of the big tile's label, so it turns on
    // both the square layout and the label itself — neither is meaningful to
    // leave off underneath it.
    final banner = currentBranding.tileTextBanner;
    final tileBig = currentBranding.tileBig || banner;

    final iconOnly = currentBranding.tileOnlyIcon || tileBig;

    // ── Tile_Text flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → show the tile name below the neumorphic image background.
    // false → icon only, no text at all.
    final showText = currentBranding.tileText || currentBranding.tileTextBanner;

    // ── Tile_3_X_3 flag ──────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → 3 icons per row.
    // false → 2 icons per row.
    final is3x3 = currentBranding.tile3x3;

    // ── Tile_Big flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → square cells, card fills them, label sits inside the card.
    // false → fixed-footprint card with the label hanging below it.

    // How many icon columns to display (3 or 2).
    final int colCount = is3x3 ? 3 : 2;

    // Priority: iconOnly > isFull > default-2-col.
    final int crossAxisCount = iconOnly ? colCount : (isFull ? 1 : 2);

    // ── Icon-only cell height ────────────────────────────────────────────
    // Derived from the exact numbers _DefaultCard lays out with, so the cell
    // and its content can never drift apart on any device.
    //
    // _FilledCard is the exception: in icon-only mode it never renders a
    // label (Tile_Text does not reach it) and its image maxes out at 75dp, so
    // it keeps the flat constants it was tuned against.
    final iconMetrics = _IconTileMetrics.resolve(
      rh: rh,
      isFull: isFull,
      is3x3: is3x3,
    );

    // The flat constants below are the *icon area* of a filled card — they
    // always sat comfortably above a bare icon, which is why the unlabelled
    // case never overflowed. A label is added on top of that rather than
    // carved out of it, so turning Tile_Text on grows the card instead of
    // shrinking its artwork.
    //
    // The neumorphic card derives its whole height instead, because there the
    // icon footprint is a known constant rather than "whatever the cell is".
    final double filledIconArea = Screen.getVerticalSize(is3x3 ? 90 : 160)
        .clamp(
          0.0,
          rh.isLargeScreen ? (is3x3 ? 130.0 : 210.0) : (is3x3 ? 100.0 : 180.0),
        );

    final double tileHeight = iconOnly
        ? (showText
              ? (currentBranding.tileBgFill
                    // The label hangs below the card, so the cell is the card
                    // plus a gap plus the label's line box.
                    ? filledIconArea + iconMetrics.gap + iconMetrics.labelHeight
                    : iconMetrics.cellHeight(showText: true))
              : filledIconArea)
        : isFull
        ? Screen.getVerticalSize(80).clamp(0.0, rh.isLargeScreen ? 120.0 : 96.0)
        : Screen.getVerticalSize(
            88,
          ).clamp(0.0, rh.isLargeScreen ? 130.0 : 100.0);

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

                // Tile_Big squares the cell off against its own measured
                // width, so it stays square at any column count and on any
                // screen rather than tracking a design constant that only
                // happens to be square at one size.
                final double cellHeight = tileBig ? cellWidth : tileHeight;

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
                              height: cellHeight,
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
    // true  → stacked layout: enlarged, centred image with the label under it.
    // false → default layout: image + text side by side.
    //
    // Implied by Tile_Big — see the note in CategorySection.
    // See the note in CategorySection: the banner implies both.
    final banner = currentBranding.tileTextBanner;
    final bannerInvert = currentBranding.tileBannerInvert;
    final bannerSquare = currentBranding.tileBannerSquare;
    final tileBig = currentBranding.tileBig || banner;

    final iconOnly = currentBranding.tileOnlyIcon || tileBig;

    // ── Tile_Only_Bg_Cricular flag ───────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → neumorphic background is a circle.
    // false → neumorphic background is a rounded square.
    final isCircular = currentBranding.tileOnlyBgCircular;

    // ── Tile_Text flag ────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → show the tile name below the neumorphic image background.
    // false → icon only, no text at all.
    final showText = currentBranding.tileText || banner;

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

    // ── Png_Bg flag ─────────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true.
    // true  → shadow is cast from the PNG's own outline; the neumorphic card
    //         is suppressed so the icon floats on the page.
    // false → the neumorphic card behaves as Tile_Bg dictates.
    final pngBg = currentBranding.pngBg;

    // ── Png_Bg_Dark flag ────────────────────────────────────────────────────
    // Only meaningful when Png_Bg=true.
    // true  → deep, tight shadow — the icon rests on the page.
    // false → soft, wide shadow — the icon floats above it.
    final pngBgDark = currentBranding.pngBgDark;

    // ── Tile_Bg_Dark flag ───────────────────────────────────────────────────
    // Only meaningful when Tile_Bg=true (and Png_Bg=false, which suppresses
    // the card).
    // true  → deep, tight neumorphic card.
    // false → soft, wide one.
    final tileBgDark = currentBranding.tileBgDark;

    // ── Tile_Big flag ───────────────────────────────────────────────────────
    // Only meaningful when Tile_Only_Icon=true: the card fills a square cell
    // and the label moves inside it.

    return isFilled
        ? _FilledCard(
            tile: tile,
            index: index,
            isFull: isFull,
            isDark: isDark,
            iconOnly: iconOnly,
            isCircular: isCircular,
            showText: showText,
            tileBig: tileBig,
            banner: banner,
            bannerInvert: bannerInvert,
            bannerSquare: bannerSquare,
            is3x3: is3x3,
            tileBgDark: tileBgDark,
            pngBg: pngBg,
            pngBgDark: pngBgDark,
            onTap: onTap,
          )
        : _DefaultCard(
            tile: tile,
            index: index,
            isFull: isFull,
            iconOnly: iconOnly,
            isCircular: isCircular,
            showText: showText,
            tileBig: tileBig,
            banner: banner,
            bannerInvert: bannerInvert,
            bannerSquare: bannerSquare,
            is3x3: is3x3,
            showBg: showBg,
            tileBgDark: tileBgDark,
            pngBg: pngBg,
            pngBgDark: pngBgDark,
            onTap: onTap,
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT CARD — original white neumorphic style (Tile_BG_FILL != true)
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultCard extends StatelessWidget {
  final EducatorTile tile;
  final int index;
  final bool isFull;
  final bool iconOnly;
  final bool isCircular;
  final bool showText;
  final bool tileBig;
  final bool banner;
  final bool bannerInvert;
  final bool bannerSquare;
  final bool is3x3;
  final bool showBg;
  final bool tileBgDark;
  final bool pngBg;
  final bool pngBgDark;
  final VoidCallback? onTap;

  const _DefaultCard({
    required this.tile,
    required this.index,
    required this.isFull,
    required this.iconOnly,
    this.isCircular = false,
    this.showText = false,
    this.tileBig = false,
    this.banner = false,
    this.bannerInvert = false,
    this.bannerSquare = false,
    this.is3x3 = true,
    this.showBg = true,
    this.tileBgDark = false,
    this.pngBg = false,
    this.pngBgDark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final radius = BorderRadius.circular(AppSizes.radiusM);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.primary.withValues(alpha: 0.47);
    final innerColor = AppColors.primary.withValues(alpha: 0.12);

    // Png_Bg applies to both layouts, so the tint is resolved once up here.
    //
    // Polarity follows the theme: black on a light canvas, white on a dark
    // one, where black would simply disappear. White carries more weight per
    // unit alpha, so it is scaled down rather than mirrored.
    final Color shadowColor = AppColors.isDark
        ? AppColors.alwaysWhite.withValues(alpha: pngBgDark ? 0.38 : 0.16)
        : AppColors.black.withValues(alpha: pngBgDark ? 0.46 : 0.18);

    // ── Image dimensions ────────────────────────────────────────────────────
    // Only the side-by-side layout sizes its image here; the icon-only sizes
    // live in [_IconTileMetrics] so the grid can reserve exactly what this
    // card paints.
    final double imgSize = Screen.getSize(isFull ? 68 : 52).clamp(
      0.0,
      rh.isLargeScreen ? (isFull ? 100.0 : 80.0) : (isFull ? 80.0 : 60.0),
    );

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
      //
      // Tile_Bg_Dark moves tint, blur and offset together — same reasoning
      // as _ContourShadow: a strong tint left on a wide blur reads as haze
      // around the card instead of elevation under it.
      // The scale is weighted heavy on purpose. The old soft step was faint
      // enough to read as no shadow at all, so it now sits where the old deep
      // step did, and the deep step goes well past it.
      // Light mode lights the card from the top-left: white highlight there,
      // dark shadow opposite. Dark mode inverts the pair outright — on a
      // near-black canvas the mark that reads as depth is a white one, so the
      // two swap roles rather than merely changing alpha. White also needs
      // less alpha than black to carry the same weight; pushed to parity it
      // blows out into a halo.
      //
      // Dragged toward black for the deep light-mode step rather than just
      // turned up: AppColors.primary at 0.6 alpha reads as a purple blob
      // under the card, not as depth.
      final Color nmDarkTint = tileBgDark
          ? Color.lerp(AppColors.primary, AppColors.black, 0.45)!
          : AppColors.primary;

      final Color nmHighlight = AppColors.isDark
          ? AppColors.black.withValues(alpha: tileBgDark ? 0.55 : 0.32)
          : AppColors.alwaysWhite.withValues(alpha: tileBgDark ? 1.0 : 0.95);
      final Color nmDepth = AppColors.isDark
          ? AppColors.alwaysWhite.withValues(alpha: tileBgDark ? 0.34 : 0.16)
          : nmDarkTint.withValues(alpha: tileBgDark ? 0.62 : 0.38);
      final double nmBlur = tileBgDark ? 8 : 10;
      final double nmSpread = tileBgDark ? 1 : 0;
      final double nmShift = tileBgDark ? 9 : 6;

      final metrics = _IconTileMetrics.resolve(
        rh: rh,
        isFull: isFull,
        is3x3: is3x3,
      );

      // Tile_Bg and Png_Bg compose rather than exclude one another: the card
      // is the surface the icon sits on, the contour shadow belongs to the
      // icon itself. Either, both, or neither is a valid look — and with both
      // on, Tile_Only_Bg_Cricular still shapes the card underneath.
      final bool showCard = showBg;

      // The footprint is constant either way: with the card on, the image is
      // inset by [padding]; with it off the padding collapses and the image
      // grows to fill the same square.
      final double containerSize = metrics.containerSize;
      final double paddingVal = showCard ? metrics.padding : 0;

      // Tile_Big lets the card fill its square cell; otherwise it keeps the
      // fixed footprint the grid reserved for it.
      final BoxDecoration? cardDecoration = showCard
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
                  color: nmHighlight,
                  blurRadius: nmBlur,
                  spreadRadius: nmSpread,
                  offset: Offset(-nmShift, -nmShift),
                ),
                // ── Depth shadow (bottom-right) ───────────────────────────────
                BoxShadow(
                  color: nmDepth,
                  blurRadius: nmBlur,
                  spreadRadius: nmSpread,
                  offset: Offset(nmShift, nmShift),
                ),
              ],
            )
          : null;

      final Widget artwork = CustomNetworkImage(
        url: tile.tileLogoURL,
        fit: BoxFit.contain,
        errorWidget: Image.asset(AppImages.bookImg),
        // Only the decoded artwork gets the shadow — the shimmer placeholder
        // keeps its plain rectangle.
        imageBuilder: pngBg
            ? (context, image) => _ContourShadow(
                color: shadowColor,
                extent: containerSize,
                deep: pngBgDark,
                child: image,
              )
            : null,
      );

      // Height pinned to the same line box the cell reserved, so a fractional
      // rounding can never push a Column past its cell.
      final Widget label = SizedBox(
        height: metrics.labelHeight,
        child: Text(
          tile.tileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          // primaryContent, not primary: on a white page they are the same
          // colour, and on the dark canvas this is the variant lifted far
          // enough to stay legible. A glow behind the glyphs was the other
          // way to buy that contrast, but any glow thickens letterforms and
          // the labels came out looking bolded.
          style: AppTypography.bodyTextLargeSemiBold.copyWith(
            color: AppColors.primaryContent,
            fontSize: metrics.fontSize,
          ),
        ),
      );

      if (banner) {
        // isDark: true asks the palette for full-strength tones rather than
        // the 55%-toward-white wash — whichever half wears the colour here
        // wears it at full saturation. The tone still varies per tile.
        final Gradient bannerTone = _TilePalette.gradientAt(
          index,
          isDark: true,
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              // Banner mode always paints a surface — falling through to a
              // transparent cell would leave the pill floating on the page.
              // Which of card and pill is the coloured one is the whole of
              // Tile_Banner_Invert; they are always opposites.
              color: bannerInvert ? null : AppColors.white,
              gradient: bannerInvert ? bannerTone : null,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: showCard
                  ? [
                      BoxShadow(
                        color: nmHighlight,
                        blurRadius: nmBlur,
                        spreadRadius: nmSpread,
                        offset: Offset(-nmShift, -nmShift),
                      ),
                      BoxShadow(
                        color: nmDepth,
                        blurRadius: nmBlur,
                        spreadRadius: nmSpread,
                        offset: Offset(nmShift, nmShift),
                      ),
                    ]
                  : null,
            ),
            child: _BannerTile(
              artwork: artwork,
              label: tile.tileName,
              index: index,
              bannerGradient: bannerInvert ? null : bannerTone,
              bannerColor: bannerInvert ? AppColors.white : null,
              // Each tone pairs with its own backdrop, so contrast survives
              // the swap: literal white on the coloured gradient, and the
              // theme-aware token on the neutral pill — where pill and text
              // flip together.
              textColor: bannerInvert
                  ? AppColors.textPrimary
                  : AppColors.alwaysWhite,
              squared: bannerSquare,
              metrics: metrics,
            ),
          ),
        );
      }

      if (tileBig) {
        // Card fills the square cell, label pinned inside it at the bottom.
        // Expanded hands the artwork whatever the label's fixed line box
        // leaves, so the Column cannot overflow whatever the cell turns out
        // to be.
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: cardDecoration,
            padding: EdgeInsets.all(
              showCard ? Screen.getSize(10) : Screen.getSize(4),
            ),
            child: showText
                ? Column(
                    children: [
                      Expanded(child: artwork),
                      SizedBox(height: metrics.gap),
                      label,
                    ],
                  )
                : artwork,
          ),
        );
      }

      final Widget nmContainer = Container(
        height: containerSize,
        width: containerSize,
        decoration: cardDecoration,
        padding: EdgeInsets.all(paddingVal),
        child: artwork,
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
                    SizedBox(height: metrics.gap),
                    label,
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
                            imageBuilder: pngBg
                                ? (context, image) => _ContourShadow(
                                    color: shadowColor,
                                    extent: imgSize,
                                    deep: pngBgDark,
                                    child: image,
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(width: Screen.getHorizontalSize(10)),
                        Expanded(
                          child: Text(
                            tile.tileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: AppColors.primaryContent,
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
  final bool isCircular;
  final bool showText;
  final bool tileBig;
  final bool banner;
  final bool bannerInvert;
  final bool bannerSquare;
  final bool is3x3;
  final bool tileBgDark;
  final bool pngBg;
  final bool pngBgDark;
  final VoidCallback? onTap;

  const _FilledCard({
    required this.tile,
    required this.index,
    required this.isFull,
    required this.isDark,
    required this.iconOnly,
    this.isCircular = false,
    this.showText = false,
    this.tileBig = false,
    this.banner = false,
    this.bannerInvert = false,
    this.bannerSquare = false,
    this.is3x3 = false,
    this.tileBgDark = false,
    this.pngBg = false,
    this.pngBgDark = false,
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

    // Nothing to sweep when the card is the neutral half — _BannerTile runs
    // the streak on the pill instead.
    if (widget.banner && !widget.bannerInvert) return;

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

    // ── Tile_Only_Bg_Cricular flag ──────────────────────────────────────────
    // Only meaningful alongside Tile_Only_Icon: the side-by-side layout needs
    // a wide card to hold its label, and a circle cannot be one.
    final bool circular = widget.iconOnly && widget.isCircular;

    // An over-large radius is clamped by RRect to half the shorter side, which
    // on a square is exactly a circle — so one value covers both shapes and
    // every borderRadius: below (decoration, clip, ink splash) stays in sync.
    final radius = BorderRadius.circular(circular ? 999 : AppSizes.radiusM);
    final gradient = _gradient;
    final staticShine = _TilePalette.shineAt(widget.index);

    // Shadow: vivid and coloured in dark mode; soft and muted in light mode.
    // Tile_Bg_Dark then moves tint, blur and offset together, exactly as it
    // does for the neumorphic card and as Png_Bg_Dark does for the icon.
    //
    // Weighted heavy to match the neumorphic scale: the soft step is what the
    // deep step used to be, and the deep step is well past it.
    //
    // Depth here comes mostly from the black veil below, not from this
    // coloured ambient — a gradient hue turned up just saturates the page
    // around the tile. So the tint is dragged toward black for the deep step
    // and the veil carries the real weight.
    final Color ambientTint = widget.tileBgDark
        ? Color.lerp(gradient.colors.first, Colors.black, 0.35)!
        : gradient.colors.first;
    final shadowColor = ambientTint.withValues(
      alpha: widget.tileBgDark
          ? (isDark ? 0.80 : 0.52)
          : (isDark ? 0.55 : 0.32),
    );
    final double cardBlur = widget.tileBgDark ? 10 : 12;
    final double cardShift = widget.tileBgDark ? 11 : 8;

    // NB: `isDark` above is the Tile_Dark *flag* — which gradient tones to
    // use — not the app theme. Shadow polarity keys off the actual theme, so
    // it reads AppColors.isDark directly.
    //
    // The veil under the card carries most of its weight, so it is the piece
    // that inverts: black on a light canvas, white on a dark one. White needs
    // roughly a third less alpha than black to land the same, so it is scaled
    // rather than mirrored.
    final double cardVeil = widget.tileBgDark ? 0.28 : 0.12;

    // Side-by-side layout: the icon sits on the gradient, so its contour
    // shadow follows the same theme polarity as everywhere else.
    final double rowIconExtent = Screen.getVerticalSize(
      widget.isFull ? 68 : 52,
    ).clamp(0.0, rh.isLargeScreen ? 90.0 : 999.0);
    final Color rowShadowColor = AppColors.isDark
        ? AppColors.alwaysWhite.withValues(
            alpha: widget.pngBgDark ? 0.38 : 0.16,
          )
        : AppColors.black.withValues(alpha: widget.pngBgDark ? 0.46 : 0.18);
    final Color veilColor = AppColors.isDark
        ? AppColors.alwaysWhite.withValues(alpha: cardVeil * 0.68)
        : AppColors.black.withValues(alpha: cardVeil);

    final metrics = _IconTileMetrics.resolve(
      rh: rh,
      isFull: widget.isFull,
      is3x3: widget.is3x3,
    );

    // Tile_Text_Banner moves the brand colour up into the pill and drops the
    // surface behind the artwork to the plain panel tone — unless
    // Tile_Banner_Invert asks for the reverse. Both coloured at once and the
    // pill has nothing to read against.
    final bool colouredCard = !widget.banner || widget.bannerInvert;

    // Gloss, shine and top-edge highlight follow the colour. They model light
    // moving across a saturated surface, so on the neutral banner-mode card
    // they would just smear — but with Tile_Banner_Invert the card is the
    // coloured half again and they belong back on it.
    //
    // The streak sits below the content layer, so the pill occludes it rather
    // than the sweep crossing the label.
    final bool decorativeLayers = colouredCard;

    final Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Coloured ambient shadow — signature of premium cards.
          BoxShadow(
            color: shadowColor,
            blurRadius: cardBlur,
            spreadRadius: 0,
            offset: Offset(0, cardShift),
          ),
          // Soft black shadow for depth separation.
          BoxShadow(
            color: veilColor,
            blurRadius: cardBlur * 0.5,
            offset: Offset(0, cardShift * 0.4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // ── Base fill ───────────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: colouredCard
                    ? BoxDecoration(gradient: gradient)
                    : BoxDecoration(color: AppColors.white),
              ),
            ),

            if (decorativeLayers) ...[
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
                  child: Container(
                    color: AppColors.alwaysWhite.withValues(alpha: 0.30),
                  ),
                ),
              ),
            ],

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
                        // ── Icon-only layout: artwork fills the card ──────
                        // The image used to be pinned to a fixed 64dp box,
                        // which left a 155dp gradient card wrapped around a
                        // postage stamp. It now takes the whole card, inset
                        // only enough to clear the rounded corners.
                        //
                        // BoxFit.contain still governs the artwork, so a
                        // square logo lands square and a wide one letterboxes
                        // rather than stretching — "full width" means the box
                        // is full width, not that the logo gets distorted to
                        // fill it.
                        // ── Icon-only layout: artwork fills the card,
                        // with the Tile_Text label inside it ─────────
                        ? (widget.banner
                              ? _bannerTile()
                              : (widget.tileBig && widget.showText
                                    ? _bigContent()
                                    : _artwork()))
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
                                  height: rowIconExtent,
                                  width: Screen.getHorizontalSize(
                                    widget.isFull ? 68 : 52,
                                  ).clamp(0.0, rh.isLargeScreen ? 90.0 : 999.0),
                                  child: CustomNetworkImage(
                                    url: widget.tile.tileLogoURL,
                                    fit: BoxFit.contain,
                                    imageBuilder: widget.pngBg
                                        ? (context, image) => _ContourShadow(
                                            color: rowShadowColor,
                                            extent: rowIconExtent,
                                            deep: widget.pngBgDark,
                                            child: image,
                                          )
                                        : null,
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
                                              ? rh.cappedFontSize(
                                                  widget.isFull ? 18 : 16,
                                                )
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

    // A circle needs a square to live in and the grid cell is not one — 3-col
    // cells land at roughly 100x90. AspectRatio takes the shorter side and
    // Center keeps the result in the middle of the cell, so the tile reads as
    // a circle rather than as a squashed oval.
    final Widget shaped = circular
        ? Center(child: AspectRatio(aspectRatio: 1, child: card))
        : card;

    // With Tile_Big the label is drawn inside the card by _bigContent, so
    // there is nothing to hang underneath it.
    if (!(widget.iconOnly && widget.showText) || widget.tileBig) return shaped;

    // Tile_Text hangs below the card, on the page — the same placement the
    // neumorphic card uses, so the two styles read as the same component with
    // a different skin.
    //
    // Expanded hands the card whatever is left once the label's fixed line box
    // is taken, so the card shrinks to fit rather than the Column overflowing,
    // no matter how the cell-height constants drift later.
    return Column(
      children: [
        Expanded(child: shaped),
        SizedBox(height: metrics.gap),
        SizedBox(
          height: metrics.labelHeight,
          child: Text(
            widget.tile.tileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // The label sits on the page canvas now, not on the gradient, so
            // the theme-aware token is the right call here — the reverse of
            // the rule that applies to text drawn *on* the card.
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.primaryContent,
              fontSize: metrics.fontSize,
            ),
          ),
        ),
      ],
    );
  }

  /// Tile_Text_Banner content — see [_BannerTile].
  Widget _bannerTile() {
    return _BannerTile(
      artwork: _artwork(),
      label: widget.tile.tileName,
      index: widget.index,
      // Always the opposite of the card — see `colouredCard` in build().
      bannerGradient: widget.bannerInvert ? null : _gradient,
      bannerColor: widget.bannerInvert ? AppColors.white : null,
      // Each tone pairs with its own backdrop, so contrast survives the swap:
      // literal white on the coloured gradient, and the theme-aware token on
      // the neutral pill — where pill and text flip together.
      textColor: widget.bannerInvert
          ? AppColors.textPrimary
          : AppColors.alwaysWhite,
      squared: widget.bannerSquare,
      metrics: _IconTileMetrics.resolve(
        rh: ResponsiveHelper.of(context),
        isFull: widget.isFull,
        is3x3: widget.is3x3,
      ),
    );
  }

  /// Tile_Big content: artwork above a label drawn *on* the gradient.
  ///
  /// Expanded hands the artwork whatever the label's fixed line box leaves,
  /// so this cannot overflow however the cell is sized.
  Widget _bigContent() {
    final metrics = _IconTileMetrics.resolve(
      rh: ResponsiveHelper.of(context),
      isFull: widget.isFull,
      is3x3: widget.is3x3,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getSize(8),
        vertical: Screen.getSize(8),
      ),
      child: Column(
        children: [
          Expanded(child: _artwork()),
          SizedBox(height: metrics.gap),
          SizedBox(
            height: metrics.labelHeight,
            child: Text(
              widget.tile.tileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                // Both tones are literal on purpose. This label is drawn on
                // the gradient, and the gradient does not follow the app
                // theme — Tile_Dark alone decides pastel or saturated — so
                // AppColors.textPrimary would flip to near-white in dark mode
                // and vanish on a pastel card.
                color: widget.isDark
                    ? AppColors.alwaysWhite
                    : AppColors.black.withValues(alpha: 0.82),
                fontSize: metrics.fontSize,
                shadows: widget.isDark
                    ? [
                        Shadow(
                          color: AppColors.black.withValues(alpha: 0.25),
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
    );
  }

  /// This tile's palette slot. Read by build() for the card fill and by
  /// [_bannerTile] for the pill — in banner mode the colour moves from the
  /// former to the latter, so both need the same source.
  LinearGradient get _gradient =>
      _TilePalette.gradientAt(widget.index, isDark: widget.isDark);

  Widget _artwork() {
    /// The artwork alone — full-bleed inside whatever box it is handed.
    return Padding(
      padding: EdgeInsets.all(Screen.getSize(6)),
      child: SizedBox.expand(
        // LayoutBuilder because the contour shadow scales
        // off the icon's rendered extent, and on a filled
        // card that comes from the cell — not from a
        // constant this widget already knows.
        child: LayoutBuilder(
          builder: (context, c) {
            final double extent = c.maxWidth < c.maxHeight
                ? c.maxWidth
                : c.maxHeight;
            return CustomNetworkImage(
              url: widget.tile.tileLogoURL,
              fit: BoxFit.contain,
              // Same polarity rule as the neumorphic
              // card: black in light mode, white in
              // dark. Note the backdrop here is the
              // gradient, not the page — so with
              // Tile_Dark off the card stays pastel in
              // both themes and a white shadow on it
              // has little to bite against.
              imageBuilder: widget.pngBg
                  ? (context, image) => _ContourShadow(
                      color: AppColors.isDark
                          ? AppColors.alwaysWhite.withValues(
                              alpha: widget.pngBgDark ? 0.38 : 0.16,
                            )
                          : AppColors.black.withValues(
                              alpha: widget.pngBgDark ? 0.46 : 0.18,
                            ),
                      extent: extent,
                      deep: widget.pngBgDark,
                      child: image,
                    )
                  : null,
              errorWidget: ColorFiltered(
                // Inverts the fallback book art to white
                // so it reads against the gradient.
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
            );
          },
        ),
      ),
    );
  }
}
