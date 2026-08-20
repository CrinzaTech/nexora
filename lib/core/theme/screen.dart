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

  // Calculate unified scaling factor to maintain aspect ratio.
  //
  // Measured against the shortest/longest side rather than raw width/height
  // so the result doesn't depend on orientation. Comparing the live width to
  // a portrait design frame made this collapse in landscape — on a 360x800
  // device it fell from ~0.99 to ~0.44, shrinking every getSize()'d icon to
  // less than half (the live class's back arrow became unusably small).
  // Portrait is unaffected: the shortest side is still the width.
  static double getScaleFactor() {
    final double shortestSide = _width < _height ? _width * 1.0 : _height * 1.0;
    final double longestSide = _width < _height ? _height * 1.0 : _width * 1.0;
    final double scaleWidth = shortestSide / FIGMA_DESIGN_WIDTH;
    final double scaleHeight = longestSide / FIGMA_DESIGN_HEIGHT;
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
    return ((px * width) / FIGMA_DESIGN_WIDTH);
  }

  static double getVerticalSize(double px) {
    return ((px * height) / FIGMA_DESIGN_HEIGHT);
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
    return (px * _width / FIGMA_DESIGN_WIDTH).clamp(8.0, 56.0);
  }

  /// Font size with a tighter cap for large screens.
  ///
  /// Equivalent to [getFontSize] but limited to 1.5× the design value,
  /// preventing extreme text enlargement on iPad or wide foldables.
  static double getFontSizeCapped(double px) {
    final scaled = (px * _width / FIGMA_DESIGN_WIDTH);
    final cap = px * 1.5; // Never more than 1.5× the original design size
    return scaled.clamp(8.0, cap > 8.0 ? cap : 56.0);
  }

  /// Horizontal size capped at [maxWidth] dp to prevent over-stretching
  /// on large screens. Defaults to 680 dp (reasonable tablet content width).
  static double getHorizontalSizeCapped(double px, {double maxWidth = 680.0}) {
    final scaled = getHorizontalSize(px);
    // Cap only when screen is wider than mobile baseline
    if (_width > 600) {
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
