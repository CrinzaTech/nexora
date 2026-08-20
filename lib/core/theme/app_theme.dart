import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';
import 'components/appbar_theme_config.dart';
import 'components/switch_theme_config.dart';

/// Export theme components for easier imports
export 'app_colors.dart';
export 'app_images.dart';
export 'app_sizes.dart';
export 'app_typography.dart';
export 'screen.dart';

/// App theme configuration
class AppTheme {
  AppTheme._();

  /// Light theme
  static ThemeData get lightTheme => _build(Brightness.light);

  /// Dark theme
  static ThemeData get darkTheme => _build(Brightness.dark);

  /// Single source for both themes.
  ///
  /// Every value that used to differ between the hand-written light and
  /// dark copies now resolves through a dynamic [AppColors] token, so
  /// one body covers both and the two can no longer drift apart.
  ///
  /// The brightness flag is set for the duration of the build and then
  /// restored, because `MaterialApp` evaluates `theme:` *and*
  /// `darkTheme:` on every build — whichever ran last would otherwise
  /// leave [AppColors] pointing at the wrong palette. The live value is
  /// set from the resolved theme in `main.dart`.
  static ThemeData _build(Brightness brightness) {
    final previous = AppColors.isDark ? Brightness.dark : Brightness.light;
    AppColors.applyBrightness(brightness);
    try {
      return _themeData(brightness);
    } finally {
      AppColors.applyBrightness(previous);
    }
  }

  static ThemeData _themeData(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        // Pin the surfaces Material derives from the seed to the brand's
        // own canvas — otherwise M3's tonal palette tints every sheet,
        // menu, and dialog indigo instead of the neutral slate the rest
        // of the app paints.
        surface: AppColors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldLight,
      // Base text/icon colours so widgets that *do* read from the theme
      // (dialogs, menus, anything Material builds internally) follow the
      // active palette instead of defaulting to black-on-dark.
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      switchTheme: SwitchThemeConfig.lightSwitchTheme,
      appBarTheme: AppbarThemeConfig.lightAppBarTheme,
      cardTheme: CardThemeData(
        elevation: AppSizes.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        color: AppColors.cardLight,
      ),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppSizes.elevationS,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          // textStyle: AppTypography.buttonMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          // textStyle: AppTypography.buttonMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          //  textStyle: AppTypography.buttonMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFillLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: BorderSide(color: AppColors.inputBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: BorderSide(color: AppColors.inputBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        // hintStyle: AppTypography.inputHint.copyWith(
        //   color: AppColors.grey500,
        // ),
        // labelStyle: AppTypography.inputLabel,
        // errorStyle: AppTypography.inputError.copyWith(
        //   color: AppColors.error,
        // ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.white,
        constraints: const BoxConstraints(maxWidth: double.infinity),
      ),
    );
  }
}
