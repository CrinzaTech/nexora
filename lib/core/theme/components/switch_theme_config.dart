import 'package:flutter/material.dart';

import '../app_colors.dart';

class SwitchThemeConfig {
  SwitchThemeConfig._();

  // Light Mode Switch Theme
  static SwitchThemeData get lightSwitchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        // if (states.contains(WidgetState.selected)) {
        //   return AppColors.switchThumbColor;
        // }
        return AppColors.switchThumbColor;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.switchBackgroundColor;
        }
        return AppColors.grey300;
      }),
    );
  }

  /// Retained for source compatibility — identical to
  /// [lightSwitchTheme]. The thumb is always white (it sits on the
  /// brand-indigo track in both themes) and the off-track resolves
  /// through the brightness-aware `AppColors.grey300`.
  static SwitchThemeData get darkSwitchTheme => lightSwitchTheme;
}
