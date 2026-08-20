import 'package:flutter/widgets.dart';

/// App sizes constants for consistent spacing and sizing
class AppSizes {
  AppSizes._();

  // ============================================
  // PADDING
  // ============================================
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // ============================================
  // MARGIN
  // ============================================
  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;
  static const double marginXXL = 48.0;

  // ============================================
  // BORDER RADIUS
  // ============================================
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusCircle = 999.0;

  // ============================================
  // ICON SIZES
  // ============================================
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 40.0;
  static const double iconXXL = 48.0;

  // ============================================
  // FONT SIZES
  // ============================================
  static const double fontXS = 10.0;
  static const double fontS = 12.0;
  static const double fontM = 14.0;
  static const double fontL = 16.0;
  static const double fontXL = 18.0;
  static const double fontXXL = 20.0;
  static const double fontXXXL = 24.0;

  // ============================================
  // ELEVATION / SHADOW
  // ============================================
  static const double elevationNone = 0.0;
  static const double elevationS = 2.0;
  static const double elevationM = 4.0;
  static const double elevationL = 8.0;
  static const double elevationXL = 12.0;

  // ============================================
  // STROKE WIDTH
  // ============================================
  static const double strokeThin = 1.0;
  static const double strokeNormal = 2.0;
  static const double strokeThick = 3.0;

  // ============================================
  // BUTTON HEIGHTS
  // ============================================
  static const double buttonHeightS = 36.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 56.0;

  // ============================================
  // INPUT FIELD HEIGHTS
  // ============================================
  static const double inputHeightS = 40.0;
  static const double inputHeightM = 48.0;
  static const double inputHeightL = 56.0;

  // ============================================
  // IMAGE SIZES
  // ============================================
  static const double imageAvatarS = 32.0;
  static const double imageAvatarM = 48.0;
  static const double imageAvatarL = 64.0;
  static const double imageThumbnailS = 64.0;
  static const double imageThumbnailM = 128.0;
  static const double imageThumbnailL = 256.0;

  // ============================================
  // SCREEN BREAKPOINTS (for responsive design)
  // ============================================
  static const double breakpointMobile = 576.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointDesktop = 1024.0;

  /// Check if current width is mobile
  static bool isMobile(double width) => width < breakpointTablet;

  /// Check if current width is tablet
  static bool isTablet(double width) =>
      width >= breakpointTablet && width < breakpointDesktop;

  /// Check if current width is desktop
  static bool isDesktop(double width) => width >= breakpointDesktop;

  // ============================================
  // EDGE INSETS HELPERS
  // ============================================
  static const EdgeInsets edgeInsetsXS = EdgeInsets.all(paddingXS);
  static const EdgeInsets edgeInsetsS = EdgeInsets.all(paddingS);
  static const EdgeInsets edgeInsetsM = EdgeInsets.all(paddingM);
  static const EdgeInsets edgeInsetsL = EdgeInsets.all(paddingL);
  static const EdgeInsets edgeInsetsXL = EdgeInsets.all(paddingXL);

  static const EdgeInsets edgeInsetsHorizontalXS =
      EdgeInsets.symmetric(horizontal: paddingXS);
  static const EdgeInsets edgeInsetsHorizontalS =
      EdgeInsets.symmetric(horizontal: paddingS);
  static const EdgeInsets edgeInsetsHorizontalM =
      EdgeInsets.symmetric(horizontal: paddingM);
  static const EdgeInsets edgeInsetsHorizontalL =
      EdgeInsets.symmetric(horizontal: paddingL);
  static const EdgeInsets edgeInsetsHorizontalXL =
      EdgeInsets.symmetric(horizontal: paddingXL);

  static const EdgeInsets edgeInsetsVerticalXS =
      EdgeInsets.symmetric(vertical: paddingXS);
  static const EdgeInsets edgeInsetsVerticalS =
      EdgeInsets.symmetric(vertical: paddingS);
  static const EdgeInsets edgeInsetsVerticalM =
      EdgeInsets.symmetric(vertical: paddingM);
  static const EdgeInsets edgeInsetsVerticalL =
      EdgeInsets.symmetric(vertical: paddingL);
  static const EdgeInsets edgeInsetsVerticalXL =
      EdgeInsets.symmetric(vertical: paddingXL);

  // ============================================
  // BORDER RADIUS HELPERS
  // ============================================
  static const BorderRadius borderRadiusXS = BorderRadius.all(
    Radius.circular(radiusXS),
  );
  static const BorderRadius borderRadiusS = BorderRadius.all(
    Radius.circular(radiusS),
  );
  static const BorderRadius borderRadiusM = BorderRadius.all(
    Radius.circular(radiusM),
  );
  static const BorderRadius borderRadiusL = BorderRadius.all(
    Radius.circular(radiusL),
  );
  static const BorderRadius borderRadiusXL = BorderRadius.all(
    Radius.circular(radiusXL),
  );
  static const BorderRadius borderRadiusCircle = BorderRadius.all(
    Radius.circular(radiusCircle),
  );
}
