import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// The "View All" action at the end of a Home section heading.
///
/// A filled pill with an arrow rather than plain coloured text, so it
/// reads as something to tap and catches the eye on a busy background.
/// Brand fill with white text, the same as the app's other primary
/// actions; in dark mode a thin off-white edge keeps a very dark brand
/// colour from disappearing into the dark page.
class ViewAllButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const ViewAllButton({
    super.key,
    required this.onTap,
    this.label = 'View All',
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: AppColors.primaryFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: AppColors.isDark
            ? BorderSide(color: AppColors.primary.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      elevation: 2,
      shadowColor: AppColors.primaryFill.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: Screen.getPadding(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: Screen.getFontSizeCapped(13),
                  height: 1.2,
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(4)),
              Icon(
                Icons.arrow_forward_rounded,
                size: Screen.getSize(15),
                color: AppColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
