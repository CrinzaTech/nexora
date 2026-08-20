import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Error state slotted into the profile card region when the load fails.
/// Mirrors the card's outer dimensions so the layout doesn't jump when
/// it swaps in for the real card.
class ProfileCardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ProfileCardError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Screen.width,
      height: Screen.getVerticalSize(200),
      padding: Screen.getPadding(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          SizedBox(height: Screen.getVerticalSize(8)),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(13),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(12)),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: Screen.getPadding(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Retry",
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                  fontSize: Screen.getFontSize(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
