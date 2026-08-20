import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder that occupies the same footprint as the real
/// profile card while the [ProfileCubit] is in its loading state, so
/// the surrounding layout doesn't shift when data arrives.
class ProfileCardShimmer extends StatelessWidget {
  const ProfileCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Screen.width,
      height: Screen.getVerticalSize(200),
      padding: Screen.getPadding(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.grey200.withValues(alpha: 0.5),
        highlightColor: AppColors.white.withValues(alpha: 0.8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Avatar shimmer
            CircleAvatar(radius: 36, backgroundColor: AppColors.white),
            SizedBox(height: Screen.getVerticalSize(8)),

            // Name shimmer
            Container(
              width: Screen.getHorizontalSize(140),
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),

            // Email shimmer
            Container(
              width: Screen.getHorizontalSize(180),
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const Spacer(),

            // DOB shimmer
            Container(
              width: Screen.getHorizontalSize(120),
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
