import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Every style below is a `get`, not a field. A `static TextStyle x = ...`
  // is lazily initialised once and cached for the process lifetime, which
  // would freeze `AppColors.textPrimary` at whatever the brightness was on
  // first access — so text would keep the startup theme's colour forever
  // after a light/dark toggle. Getters re-evaluate per read, which also
  // picks up Screen.getFontSize() after a screen-metrics change.
  //MARK: H1
  static TextStyle get h1Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(48),
    height: 56 / 48,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  static TextStyle get h1SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(48),
    height: 56 / 48,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  static TextStyle get h1Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(48),
    height: 56 / 48,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: H2
  static TextStyle get h2Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(40),
    height: 48 / 40,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h2SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(40),
    height: 48 / 40,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h2Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(40),
    height: 48 / 40,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: H3
  static TextStyle get h3Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(32),
    height: 40 / 32,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h3SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(32),
    height: 40 / 32,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h3Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(32),
    height: 40 / 32,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: H4
  static TextStyle get h4Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(24),
    height: 32 / 24,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h4SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(24),
    height: 32 / 24,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h4Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(24),
    height: 32 / 24,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: H5
  static TextStyle get h5Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(20),
    height: 28 / 20,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h5SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(20),
    height: 28 / 20,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h5Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(20),
    height: 28 / 20,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: H6
  static TextStyle get h6Medium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h6SemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get h6Bold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Body Text Xtra Large
  static TextStyle get bodyTextXtraLargeMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextXtraLargeSemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextXtraLargeBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(18),
    height: 26 / 18,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Body Text Large
  static TextStyle get bodyTextLargeMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(16),
    height: 24 / 16,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextLargeSemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(16),
    height: 24 / 16,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextLargeBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(16),
    height: 24 / 16,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Body Text Medium
  static TextStyle get bodyTextMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(14),
    height: 22 / 14,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextSemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(14),
    height: 22 / 14,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(14),
    height: 22 / 14,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Body Text Small
  static TextStyle get bodyTextSmallMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(12),
    height: 20 / 12,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextSmallSemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(12),
    height: 20 / 12,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextSmallBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(12),
    height: 20 / 12,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Body Text Xtra Small
  static TextStyle get bodyTextXtraSmallMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(10),
    height: 18 / 10,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextXtraSmallSemiBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(10),
    height: 18 / 10,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyTextXtraSmallBold => GoogleFonts.dmSans(
    fontWeight: FontWeight.w700,
    fontSize: Screen.getFontSize(10),
    height: 18 / 10,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  //MARK: Button Styles
  static TextStyle get buttonLarge => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(16),
    height: 24 / 16,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get buttonMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(14),
    height: 20 / 14,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get buttonSmall => GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: Screen.getFontSize(12),
    height: 18 / 12,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  //MARK: Label Styles
  static TextStyle get labelLarge => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(14),
    height: 20 / 14,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelMedium => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(12),
    height: 18 / 12,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelSmall => GoogleFonts.dmSans(
    fontWeight: FontWeight.w500,
    fontSize: Screen.getFontSize(10),
    height: 16 / 10,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );
}
