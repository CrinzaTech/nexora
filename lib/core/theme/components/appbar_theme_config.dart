import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_sizes.dart';
import '../app_typography.dart';

class AppbarThemeConfig {
  AppbarThemeConfig._();

  // Appbar theme. `AppColors.white` / `grey900` / `textPrimary` are
  // brightness-aware, so this one definition already resolves correctly
  // in both themes — see the dynamic-token block in app_colors.dart.
  static AppBarTheme get lightAppBarTheme {
    return AppBarTheme(
      centerTitle: true,
      elevation: AppSizes.elevationNone,
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.grey900,
      titleTextStyle: AppTypography.h5SemiBold.copyWith(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Retained for source compatibility — identical to
  /// [lightAppBarTheme], which already adapts to the active brightness.
  static AppBarTheme get darkAppBarTheme => lightAppBarTheme;
}
