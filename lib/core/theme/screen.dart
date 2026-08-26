// ignore_for_file: non_constant_identifier_names

import 'dart:ui';
import 'package:flutter/material.dart';

class Screen {
  // Figma design dimensions
  static num FIGMA_DESIGN_WIDTH = 360;
  static num FIGMA_DESIGN_HEIGHT = 812;
  static num FIGMA_DESIGN_STATUS_BAR = MediaQueryData.fromView(
    PlatformDispatcher.instance.views.first,
  ).viewPadding.top;

  static num _width = 360; // Default to Figma design width
  static num _height = 812; // Default to Figma design height

  void adaptDeviceScreenSize(BuildContext context) {
    final size = MediaQuery.of(context).size;

    _width = size.width;
    _height = size.height;
  }

  // Responsive Radius Size
  static double getRadius(double px) {
    return getSize(px);
  }

  /// The device's narrow dimension, whichever way it is being held.
  ///
  /// Every measurement below is taken against this (or [_longestSide])
  /// rather than raw width/height, because the Figma frame this scales
  /// from is a *portrait* one. Comparing the live width to a 360-wide
  /// design frame makes each of these swing wildly the moment the device
  /// turns: on a 360x800 phone the width jumps to 800, so anything keyed
  /// to it grows 2.2x and anything keyed to the height collapses to 0.44x.
  ///
  /// Portrait is unaffected — the shortest side *is* the width there — so
  /// this only ever changes what landscape gets, which is the live class
  /// and webinar room stages. Everything else is portrait-locked in
  /// `main()`.
  static double get _shortestSide =>
      _width < _height ? _width * 1.0 : _height * 1.0;

  static double get _longestSide =>
      _width < _height ? _height * 1.0 : _width * 1.0;

  // Calculate unified scaling factor to maintain aspect ratio.
  //
  // Keyed to the shortest/longest side for the reason above: this used to
  // read raw width, and on a 360x800 device in landscape it fell from
  // ~0.99 to ~0.44, shrinking every getSize()'d icon to less than half
  // (the live class's back arrow became unusably small).
  static double getScaleFactor() {
    final double scaleWidth = _shortestSide / FIGMA_DESIGN_WIDTH;
    final double scaleHeight = _longestSide / FIGMA_DESIGN_HEIGHT;
    return scaleWidth < scaleHeight ? scaleWidth : scaleHeight;
  }

  // Width and Height
  static double get width => _width * 1.0;
  static double get height => _height * 1.0;

  // Dynamic Safe Height Calculation
  static double getSafeHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom;
  }

  // Responsive Sizing Methods
  static double getHorizontalSize(double px) {
    return ((px * _shortestSide) / FIGMA_DESIGN_WIDTH);
  }

  static double getVerticalSize(double px) {
    return ((px * _longestSide) / FIGMA_DESIGN_HEIGHT);
  }

  static double getSize(double px) {
    var scaleFactor = getScaleFactor();
    return px * scaleFactor;
  }

  /// Font size scaled from the Figma baseline.
  ///
  /// The upper clamp is conservative (56) — on large screens (tablets, foldables)
  /// use [ResponsiveHelper.cappedFontSize] or [getFontSizeCapped] instead.
  static double getFontSize(double px) {
    return (px * _shortestSide / FIGMA_DESIGN_WIDTH).clamp(8.0, 56.0);
  }

  /// Font size with a tighter cap for large screens.
  ///
  /// Equivalent to [getFontSize] but limited to 1.5× the design value,
  /// preventing extreme text enlargement on iPad or wide foldables.
  static double getFontSizeCapped(double px) {
    final scaled = (px * _shortestSide / FIGMA_DESIGN_WIDTH);
    final cap = px * 1.5; // Never more than 1.5× the original design size
    return scaled.clamp(8.0, cap > 8.0 ? cap : 56.0);
  }

  /// Horizontal size capped at [maxWidth] dp to prevent over-stretching
  /// on large screens. Defaults to 680 dp (reasonable tablet content width).
  static double getHorizontalSizeCapped(double px, {double maxWidth = 680.0}) {
    final scaled = getHorizontalSize(px);
    // Cap only when the device is genuinely bigger than the mobile
    // baseline — not merely turned sideways, which is what reading raw
    // width made this think.
    if (_shortestSide > 600) {
      return scaled.clamp(0.0, px * 1.5); // max 1.5× on larger screens
    }
    return scaled;
  }

  // Padding and Margin Methods
  static EdgeInsets getPadding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return getMarginOrPadding(
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  static EdgeInsets getMargin({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return getMarginOrPadding(
      all: all,
      horizontal: horizontal,
      vertical: vertical,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  static EdgeInsets getMarginOrPadding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    // Handle 'all' parameter - overrides everything
    if (all != null) {
      return EdgeInsets.all(getSize(all));
    }

    // Calculate each side with precedence: specific > horizontal/vertical
    double finalLeft = getHorizontalSize(left ?? horizontal ?? 0);
    double finalTop = getVerticalSize(top ?? vertical ?? 0);
    double finalRight = getHorizontalSize(right ?? horizontal ?? 0);
    double finalBottom = getVerticalSize(bottom ?? vertical ?? 0);

    return EdgeInsets.only(
      left: finalLeft,
      top: finalTop,
      right: finalRight,
      bottom: finalBottom,
    );
  }
}
