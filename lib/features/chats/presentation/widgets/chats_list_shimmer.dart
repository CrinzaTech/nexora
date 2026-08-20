import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Placeholder list shown while chat groups are loading. Mirrors the
/// real tile layout (avatar + two text lines) so the swap in to real
/// content doesn't reflow.
class ChatsListShimmer extends StatelessWidget {
  const ChatsListShimmer({super.key});

  static const _placeholderCount = 8;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(vertical: 8),
        itemCount: _placeholderCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.grey200,
          indent: Screen.getHorizontalSize(25),
          endIndent: Screen.getHorizontalSize(25),
        ),
        itemBuilder: (_, __) => Container(
          padding: Screen.getPadding(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: Screen.getHorizontalSize(180),
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(6)),
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
            ],
          ),
        ),
      ),
    );
  }
}
