import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'dart:math' as math;

import 'package:nexora/features/home_live/presentation/bloc/home_live_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  static const double _bottom = 10;
  static const double _itemGap = 4;
  static const double _shadowInset = 5;

  /// Height of the row for a screen [width]: four square icons, each
  /// inset by [_itemGap] on both sides, plus the row's own padding.
  static double extentFor(double width) {
    final cell = (width - _side * 2) / 4;
    return topPadding + (cell - _itemGap * 2) + _bottom;
  }

  /// The red ripple behind the Live Events icon: on while there is any live
  /// class or webinar on the way (scheduled or running), quicker and
  /// stronger while one is on air right now. Null when there is nothing.
  Widget? _liveRipple(BuildContext context) {
    final (classes, classesLive) = context
        .watch<HomeLiveCubit>()
        .state
        .maybeWhen(
          loaded: (sessions, liveCount, _, __, ___, ____) =>
              (sessions.length, liveCount),
          orElse: () => (0, 0),
        );
    final (webinars, webinarsLive) = context
        .watch<WebinarsCubit>()
        .state
        .maybeWhen(
          loaded: (items, liveCount, _, __, ___, ____) =>
              (items.length, liveCount),
          orElse: () => (0, 0),
        );
    if (classes + webinars == 0) return null;
    return _RedRipple(live: classesLive + webinarsLive > 0);
  }

  Widget _tile(BuildContext context, _DiscoverItem item) {
    // A soft drop shadow under the round artwork, drawn as a circle a hair
    // inside the image so it hugs the disc rather than its square canvas.
    final ripple = item.pulse ? _liveRipple(context) : null;
    final image = Stack(
      fit: StackFit.expand,
      // The ripple spreads past the icon's own box.
      clipBehavior: Clip.none,
      children: [
        // Behind the artwork, so the rings spread out from under it.
        if (ripple != null) Positioned.fill(child: ripple),
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
        pulse: true,
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

  /// Shows the live ripple behind the icon when something is on the way.
  final bool pulse;

  const _DiscoverItem({
    required this.asset,
    required this.label,
    required this.onTap,
    this.pulse = false,
  });
}

/// Two red rings that swell out from behind the icon and fade, one half a
/// cycle behind the other — a pulse that says "something is happening in
/// here". [live] (on air now) makes it faster and stronger than the calm
/// pulse for something merely scheduled.
class _RedRipple extends StatefulWidget {
  final bool live;

  const _RedRipple({required this.live});

  @override
  State<_RedRipple> createState() => _RedRippleState();
}

class _RedRippleState extends State<_RedRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  Duration get _period => Duration(milliseconds: widget.live ? 1400 : 2400);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void didUpdateWidget(_RedRipple old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      _ctrl.duration = _period;
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RipplePainter(
            progress: _ctrl,
            // A deeper red than the plain error colour, so the rings hold
            // up against the white icon and page.
            color: const Color(0xFFD50000),
            strength: widget.live ? 1.0 : 0.85,
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final double strength;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.strength,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    for (var ring = 0; ring < 2; ring++) {
      final t = (progress.value + ring * 0.5) % 1.0;
      final eased = Curves.easeOut.transform(t);
      final radius = base * (0.78 + 0.5 * eased);
      final fade = math.pow(1 - t, 1.0).toDouble() * strength;
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = color.withValues(alpha: 0.5 * fade),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.color != color || old.strength != strength;
}
