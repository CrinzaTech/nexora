import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Reusable profile list tile — leading asset icon + title + trailing
/// chevron, used in every section of the profile page (Payments,
/// Account Settings, Help & Support, Legal).
class CustomProfileListTileWidget extends StatelessWidget {
  final String title;

  /// Asset path for the leading icon. Give this or [leadingIconData].
  final String? leadingIcon;

  /// A Material icon instead of an asset — for rows with no matching
  /// monochrome PNG. Drawn at the asset's size, in the text colour.
  final IconData? leadingIconData;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Recolour [leadingIcon] to match the active text colour.
  ///
  /// The tile icons are flat monochrome navy PNGs on transparent, which
  /// all but disappear against the dark surface. Tinting keeps the
  /// alpha and just swaps the ink, and in light mode the tint equals the
  /// colour already baked into the asset — so this is a no-op there.
  /// Pass `false` for a multi-colour asset, which tinting would flatten.
  final bool tintLeadingIcon;

  const CustomProfileListTileWidget({
    super.key,
    this.onTap,
    required this.title,
    this.leadingIcon,
    this.leadingIconData,
    this.trailing,
    this.tintLeadingIcon = true,
  }) : assert(
         leadingIcon != null || leadingIconData != null,
         'Give leadingIcon or leadingIconData',
       );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => debugPrint("Navigate to $title"),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          child: Padding(
            padding: Screen.getPadding(vertical: 12, horizontal: 15),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: Screen.getSize(20),
                  child: leadingIconData != null
                      ? Icon(
                          leadingIconData,
                          size: Screen.getSize(20),
                          color: AppColors.textPrimary,
                        )
                      : Image.asset(
                          leadingIcon!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          color: tintLeadingIcon ? AppColors.textPrimary : null,
                        ),
                ),
                SizedBox(width: Screen.getHorizontalSize(15)),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: Screen.getFontSizeCapped(14),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                trailing ??
                    SizedBox.square(
                      dimension: Screen.getSize(20),
                      child: Image.asset(
                        AppImages.arrowRightIcon,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        // Same monochrome-PNG problem as the leading
                        // icon — see [tintLeadingIcon].
                        color: AppColors.textPrimary,
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
