import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

/// The 6-box OTP entry row.
///
/// The boxes sit on a frosted glass sheet, so they have to stay legible
/// over *any* backdrop the sheet is composited against — including a
/// pure-white background image, where a borderless near-white fill
/// disappears completely. The recipe mirrors `CustomTextFormField`: a
/// solid surface fill, a grey border while empty and a primary border
/// once focused or filled, plus a soft contact shadow that lifts each
/// box off the sheet regardless of what shows through the glass.
class OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const OtpInputField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pinShadow = [
      BoxShadow(
        color: AppColors.black.withValues(alpha: AppColors.isDark ? 0.40 : 0.08),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];

    BoxDecoration boxDecoration(Color border, double width) => BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      // Border.all keeps every side one colour. A non-uniform Border
      // alongside a borderRadius throws in Border.paint and takes the
      // whole subtree's paint with it.
      border: Border.all(color: border, width: width),
      boxShadow: pinShadow,
    );

    final defaultPinTheme = PinTheme(
      width: Screen.getHorizontalSizeCapped(50),
      height: Screen.getHorizontalSizeCapped(55),
      textStyle: AppTypography.h4SemiBold.copyWith(
        color: AppColors.textPrimary,
        fontSize: Screen.getFontSizeCapped(22),
      ),
      decoration: boxDecoration(AppColors.grey300, 1),
    );

    return Pinput(
      length: 6,
      onChanged: onChanged,
      controller: controller,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyWith(
        decoration: boxDecoration(AppColors.primary, 1.5),
      ),
      // A box already holding a digit keeps the primary border, thinner
      // than the focused one, so progress through the code reads at a
      // glance without competing with the cursor position.
      submittedPinTheme: defaultPinTheme.copyWith(
        decoration: boxDecoration(AppColors.primary, 1),
      ),
      followingPinTheme: defaultPinTheme,
      // iOS: the system suggests the OTP from Messages in the keyboard
      // toolbar automatically when this hint is set. Android handles
      // autofill via CodeAutoFill / SMS Retriever in the page's State.
      autofillHints: const [AutofillHints.oneTimeCode],
    );
  }
}
