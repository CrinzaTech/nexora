import 'package:nexora/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets a page's top bar sit see-through over the background photo until
/// its content scrolls up under it, then turn solid so the cards don't
/// show through the title and status bar.
///
/// Feed [handleScrolledUnder] from a [NotificationListener] placed directly
/// around the scrolling content — inside a NestedScrollView's `body`, not
/// around the NestedScrollView itself, so the header's own scroll is not
/// mistaken for content passing beneath it.
///
/// The bar fades between the two rather than snapping, so the host must
/// also mix in a ticker provider (`SingleTickerProviderStateMixin` or
/// `TickerProviderStateMixin`) ahead of this mixin.
mixin ScrolledUnderMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  bool _scrolledUnder = false;

  /// 0 → see-through, 1 → solid. Rebuilds the page on each tick so every
  /// piece of the bar (app bar, status band, pinned strips) fades together.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addListener(() => setState(() {}));

  /// True once the content has moved off its top.
  bool get scrolledUnder => _scrolledUnder;

  /// Fill for the top bar and anything painted as part of it (status-bar
  /// band, pinned search/tab strips). Fades the white in by alpha alone —
  /// a straight lerp from transparent (black) would grey it mid-fade.
  Color get topBarColor =>
      AppColors.white.withValues(alpha: Curves.easeOut.transform(_fade.value));

  /// Status-bar icons for the bar. A transparent AppBar would otherwise
  /// guess "dark background" and paint white icons over a light photo.
  SystemUiOverlayStyle get topBarOverlayStyle =>
      (AppColors.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent);

  bool handleScrolledUnder(ScrollNotification notification) {
    final past = scrolledPastTop(notification);
    if (past != null) setScrolledUnder(past);
    return false;
  }

  void setScrolledUnder(bool value) {
    if (value == _scrolledUnder || !mounted) return;
    _scrolledUnder = value;
    // No setState here: the controller rebuilds from its next tick, so
    // this is safe even when a scroll position is corrected mid-layout.
    value ? _fade.forward() : _fade.reverse();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }
}

/// Whether [notification]'s list has scrolled off its top. Null for
/// notifications that say nothing about that — sideways scrolls (tab
/// pages, carousels) and scrollables nested inside the list.
bool? scrolledPastTop(ScrollNotification notification) {
  if (notification.depth != 0) return null;
  final metrics = notification.metrics;
  if (metrics.axis != Axis.vertical) return null;
  return metrics.pixels > metrics.minScrollExtent;
}
