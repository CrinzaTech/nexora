import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class RatingAndReviewRowWidget extends StatelessWidget {
  final String rating;
  final String reviewCount;
  const RatingAndReviewRowWidget({
    super.key,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: Screen.getHorizontalSize(55),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: Screen.getHorizontalSizeCapped(16),
                child: Image.asset(AppImages.starIconColored),
              ),
              SizedBox(width: Screen.getHorizontalSize(5)),
              Text(
                rating.toString(),
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.grey300,
                  fontSize: Screen.getFontSize(14),
                ),
              ),
            ],
          ),
        ),

        Container(
          width: Screen.getHorizontalSizeCapped(5),
          height: Screen.getHorizontalSizeCapped(5),
          decoration: BoxDecoration(
            color: AppColors.grey300,
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
        ),
        SizedBox(width: Screen.getHorizontalSize(5)),

        Expanded(
          child: Text(
            reviewCount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.grey300,
              fontSize: Screen.getFontSize(14),
            ),
          ),
        ),
      ],
    );
  }
}
