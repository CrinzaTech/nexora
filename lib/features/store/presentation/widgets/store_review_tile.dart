import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// One learner review, with the seller's reply under it when there is one.
class StoreReviewTile extends StatelessWidget {
  final StoreReview review;

  const StoreReviewTile({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  Utils.getInitials(r.learnerName),
                  style: AppTypography.bodyTextXtraSmallBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.learnerName, style: AppTypography.bodyTextSemiBold),
                    if (r.createdAt != null)
                      Text(
                        StoreFormat.date(r.createdAt!),
                        style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              if (r.isPinned) ...[
                Icon(Icons.push_pin_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
              ],
              StoreRatingPill(rating: r.rating.toDouble(), count: 1),
            ],
          ),
          if (r.comment != null) ...[
            const SizedBox(height: 8),
            Text(
              r.comment!,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (r.sellerReply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Seller replied',
                        style: AppTypography.bodyTextXtraSmallBold.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.sellerReply!,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Average, stars, count, and a bar per star level (C4 `rating`).
class StoreRatingSummaryView extends StatelessWidget {
  final StoreRatingSummary rating;

  const StoreRatingSummaryView({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final maxCount = rating.stars.fold<int>(0, (m, c) => c > m ? c : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            children: [
              Text(
                StoreFormat.rating(rating.average),
                style: AppTypography.h3Bold.copyWith(height: 1),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final d = rating.average - i;
                  return Icon(
                    d >= 0.75
                        ? Icons.star_rounded
                        : d >= 0.25
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: AppColors.ratingColor,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${StoreFormat.count(rating.count)} rating'
                '${rating.count == 1 ? '' : 's'}',
                style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$star★',
                          style: AppTypography.bodyTextXtraSmallBold,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: maxCount == 0
                                ? 0
                                : rating.stars[star - 1] / maxCount,
                            backgroundColor: AppColors.grey100,
                            color: StoreRatingPill.colorFor(star.toDouble()),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          StoreFormat.count(rating.stars[star - 1]),
                          textAlign: TextAlign.right,
                          style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                            color: AppColors.mutedTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
