import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';

/// Person Card — shows real profile data when available
class PersonCardWidget extends StatelessWidget {
  final UserProfileModel? profile;

  const PersonCardWidget({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Use padding-based sizing instead of a fixed height so the card
      // adapts to any screen size (iPad, Fold, phone) without overflowing.
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(16),
        vertical: Screen.getVerticalSize(20),
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar
          if (profile?.userProfileImage != null &&
              profile!.userProfileImage!.isNotEmpty)
            CircleAvatar(
              radius: 36,
              backgroundImage: CachedNetworkImageProvider(
                profile!.userProfileImage!,
                cacheKey: Utils.imageCacheKey(profile!.userProfileImage!),
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.6),
                    AppColors.primary.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                Utils.getInitials(profile?.name ?? '?'),
                style: AppTypography.h6SemiBold.copyWith(
                  color: AppColors.alwaysWhite,
                  fontSize: Screen.getFontSize(24),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          SizedBox(height: Screen.getVerticalSize(5)),

          // Name
          Text(
            profile?.name ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h5SemiBold.copyWith(
              fontSize: Screen.getFontSizeCapped(20),
            ),
          ),

          // Phone / Email
          Text(
            profile?.email ?? profile?.phoneNumber ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextMedium.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: Screen.getFontSizeCapped(14),
              color: AppColors.mutedTextPrimary,
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(12).clamp(8.0, 16.0)),

          // Join Date
          if (profile?.joinAt != null)
            Text(
              Utils.formatJoinedAt(profile!.joinAt),
              style: AppTypography.bodyTextMedium.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: Screen.getFontSizeCapped(12),
                color: AppColors.mutedTextPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
