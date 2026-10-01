import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Logout as a tile card, matching the other profile sections — a
/// [PremiumSurface] holding one row — rather than a standalone filled
/// pill. Red ink on the icon, label and chevron is what marks it as the
/// session-ending row; the same treatment as the Delete Account row.
class LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const LogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.error.withValues(alpha: 0.1),
          highlightColor: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Padding(
            padding: Screen.getPadding(vertical: 12, horizontal: 15),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: Screen.getSize(20),
                  color: AppColors.error,
                ),
                SizedBox(width: Screen.getHorizontalSize(15)),
                Expanded(
                  child: Text(
                    'Logout',
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.error,
                      fontSize: Screen.getFontSizeCapped(14),
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: Screen.getSize(20),
                  child: Image.asset(
                    AppImages.arrowRightIcon,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
