import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Row of four quick-access icons shown right under the home banner.
class DiscoverIconsRow extends StatelessWidget {
  /// Top padding when the row scrolls with the page.
  static const double topPadding = 20;

  /// Tighter top padding used while the row is pinned under the AppBar.
  static const double pinnedTopPadding = 8;

  final double top;

  /// Bottom padding; defaults to the page-row value.
  final double? bottom;

  /// Fixed icon size. Null (the default) lets four icons share the row's
  /// width; set, they are this size and spread evenly, like the navbar's.
  final double? iconSize;

  const DiscoverIconsRow({
    super.key,
    this.top = topPadding,
    this.bottom,
    this.iconSize,
  });

  static const double _side = 12;
  static const double _bottom = 12;
  static const double _itemGap = 4;
  static const double _shadowInset = 5;

  /// Height of the row for a screen [width]: four square icons, each
  /// inset by [_itemGap] on both sides, plus the row's own padding.
  static double extentFor(double width) {
    final cell = (width - _side * 2) / 4;
    return topPadding + (cell - _itemGap * 2) + _bottom;
  }

  Widget _tile(BuildContext context, _DiscoverItem item) {
    // A soft drop shadow under the round artwork, drawn as a circle a hair
    // inside the image so it hugs the disc rather than its square canvas.
    final image = Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(_shadowInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(
                    alpha: AppColors.isDark ? 0.55 : 0.28,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        Image.asset(item.asset, semanticLabel: item.label, fit: BoxFit.contain),
      ],
    );
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      // Square, sized by the width it is given: the row has no height
      // bound of its own, and an expanding Stack needs one.
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: iconSize == null ? _itemGap : 0,
        ),
        child: AspectRatio(aspectRatio: 1, child: image),
      ),
    );
    if (iconSize == null) {
      // Each icon keeps a four-across cell however many there are, so
      // removing one doesn't blow the rest up; the row is centred.
      final cell = (MediaQuery.of(context).size.width - _side * 2) / 4;
      return SizedBox(width: cell, child: tappable);
    }
    // Flexible + a max size: on a narrow screen the icons shrink a little
    // rather than overflow the row.
    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: iconSize!, maxHeight: iconSize!),
        child: tappable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_DiscoverItem>[
      _DiscoverItem(
        asset: 'assets/icons/discover/live.png',
        label: 'Live Events',
        onTap: () => context.push(AppRoutes.liveEvents),
      ),
      _DiscoverItem(
        asset: 'assets/icons/discover/free.png',
        label: 'Free Courses',
        onTap: () => CustomSnackbar.info(
          context,
          title: 'Free Courses',
          message: 'Coming soon',
        ),
      ),
      _DiscoverItem(
        asset: 'assets/icons/discover/store.png',
        label: 'Store & More',
        // No store screen yet.
        onTap: () => CustomSnackbar.info(
          context,
          title: 'Store & More',
          message: 'Coming soon',
        ),
      ),
      _DiscoverItem(
        asset: 'assets/icons/discover/news.png',
        label: 'News',
        onTap: () =>
            CustomSnackbar.info(context, title: 'News', message: 'Coming soon'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: iconSize == null ? _side : 6,
        right: iconSize == null ? _side : 6,
        top: top,
        bottom: bottom ?? _bottom,
      ),
      child: Row(
        mainAxisAlignment: iconSize == null
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [for (final item in items) _tile(context, item)],
      ),
    );
  }
}

class _DiscoverItem {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const _DiscoverItem({
    required this.asset,
    required this.label,
    required this.onTap,
  });
}
