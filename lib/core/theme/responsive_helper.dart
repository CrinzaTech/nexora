import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Device category derived from logical screen width.
enum DeviceType {
  /// Folded phone or narrow phone (< 600 dp)
  phone,

  /// Unfolded foldable (600–720 dp) — e.g. Samsung Galaxy Z Fold inner display
  fold,

  /// Tablet (> 720 dp) — e.g. iPad
  tablet,
}

/// Responsive layout helper.
///
/// Provides device-aware sizing so the UI does not break on large screens
/// (iPad, Samsung Galaxy Fold unfolded). All values are derived from the
/// logical screen width so they work correctly for both orientations.
///
/// Usage:
/// ```dart
/// final rh = ResponsiveHelper.of(context);
/// Container(
///   constraints: BoxConstraints(maxWidth: rh.maxContentWidth),
/// )
/// ```
class ResponsiveHelper {
  const ResponsiveHelper._({
    required this.screenWidth,
    required this.screenHeight,
    required this.deviceType,
  });

  factory ResponsiveHelper.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    return ResponsiveHelper._(
      screenWidth: w,
      screenHeight: size.height,
      deviceType: _classify(w),
    );
  }

  final double screenWidth;
  final double screenHeight;
  final DeviceType deviceType;

  // ── Device type helpers ─────────────────────────────────────────────────────

  bool get isPhone => deviceType == DeviceType.phone;
  bool get isFold => deviceType == DeviceType.fold;
  bool get isTablet => deviceType == DeviceType.tablet;

  bool get isIpad =>
      defaultTargetPlatform == TargetPlatform.iOS && screenWidth >= 600;

  bool get isLargeScreen => isFold || isTablet || isIpad;

  static DeviceType _classify(double width) {
    if (width > 720) return DeviceType.tablet;
    if (width > 600) return DeviceType.fold;
    return DeviceType.phone;
  }

  // ── Max content width ───────────────────────────────────────────────────────

  /// Maximum width for the main scrollable content column.
  ///
  /// On tablets the content is centred within this cap so it doesn't
  /// stretch uncomfortably across the full ~820 dp iPad screen.
  double get maxContentWidth {
    switch (deviceType) {
      case DeviceType.tablet:
        return 680;
      case DeviceType.fold:
        return screenWidth; // Fold already looks fine at full width
      case DeviceType.phone:
        return screenWidth;
    }
  }

  /// Maximum width for modal/bottom-sheet content (enrollment, dialogs).
  double get maxModalWidth {
    switch (deviceType) {
      case DeviceType.tablet:
        return 560;
      case DeviceType.fold:
        return 520;
      case DeviceType.phone:
        return screenWidth;
    }
  }

  /// Maximum width for the floating bottom nav bar pill.
  double get maxNavBarWidth {
    switch (deviceType) {
      case DeviceType.tablet:
        return 480;
      case DeviceType.fold:
        return 420;
      case DeviceType.phone:
        return screenWidth;
    }
  }

  // ── Font scale cap ──────────────────────────────────────────────────────────

  /// A capped font-size multiplier applied on top of [Screen.getFontSize].
  ///
  /// On phone, 1.0 → no change from existing logic.
  /// On fold/tablet, slightly below 1.0 so fonts don't over-scale.
  double get fontScaleFactor {
    switch (deviceType) {
      case DeviceType.tablet:
        return 0.62; // Prevents extreme enlargement: 360→820 = 2.28× → we cap at ~1.4×
      case DeviceType.fold:
        return 0.72;
      case DeviceType.phone:
        return 1.0;
    }
  }

  // ── Horizontal padding ──────────────────────────────────────────────────────

  /// Default horizontal padding for screen edges.
  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.tablet:
        return 24;
      case DeviceType.fold:
        return 20;
      case DeviceType.phone:
        return 16;
    }
  }

  // ── Course card width ───────────────────────────────────────────────────────

  /// Width of a featured-course card in the horizontal list.
  /// Capped so cards don't grow absurdly large on tablets.
  double get courseCardWidth {
    switch (deviceType) {
      case DeviceType.tablet:
        return screenWidth * 0.85;
      case DeviceType.fold:
        return screenWidth * 0.85;
      case DeviceType.phone:
        return 260;
    }
  }

  // ── Capped font size ────────────────────────────────────────────────────────

  /// Returns a font size capped for the current device category.
  ///
  /// This overrides [Screen.getFontSize] on large screens to prevent
  /// text from scaling too aggressively.
  double cappedFontSize(double designPx) {
    // Linear scale from 360 dp baseline, then cap how far it's allowed to
    // grow. The tablet/fold branches used to ignore `raw` entirely and
    // apply a flat 2.025x/2.4x multiplier of the *design* size regardless
    // of actual screen width — on a near-square unfolded fold that put a
    // real 18px button label past 40px, oversizing headings and clipping
    // short labels (e.g. "Apply") past their fixed-height containers.
    final raw = designPx * (screenWidth / 360.0);
    switch (deviceType) {
      case DeviceType.tablet:
        return raw.clamp(8.0, designPx * 1.35);
      case DeviceType.fold:
        return raw.clamp(8.0, designPx * 1.25);
      case DeviceType.phone:
        return raw.clamp(8.0, 56.0);
    }
  }

  // ── Centered content wrapper ────────────────────────────────────────────────

  /// Wraps [child] in a centered, max-width constrained box.
  /// On phone, returns [child] unchanged.
  Widget centeredContent(Widget child) {
    if (isPhone) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
