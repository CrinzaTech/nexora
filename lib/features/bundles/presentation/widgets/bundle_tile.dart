import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/courses/presentation/widgets/course_cover.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Opens the bundle page. Awaitable so a caller can refresh on return.
Future<void> openBundle(BuildContext context, int bundleId) =>
    context.push('${AppRoutes.bundleDetail}?id=$bundleId');

/// One bundle as a card — the Home rail, the course-page rail and the
/// full list all use it. Every figure is the server's (§1 rule 1).
class BundleTile extends StatelessWidget {
  final BundleCard bundle;

  /// Fixed width for a horizontal rail; null fills the parent.
  final double? width;

  const BundleTile({super.key, required this.bundle, this.width});

  static const double _pad = 8;

  /// Height of a tile [width] wide, so a horizontal rail can bound its
  /// cross axis without guessing. Follows the learner's text size.
  static double heightFor(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final image = (width - _pad * 2) * 9 / 16;
    final title = scaler.scale(Screen.getFontSize(14)) * 1.25 * 2;
    final price = scaler.scale(AppTypography.bodyTextLargeBold.fontSize ?? 16);
    final sub = scaler.scale(AppTypography.bodyTextSmallMedium.fontSize ?? 12);
    return 10 + image + 10 + title + 8 + price * 1.3 + 4 + sub * 1.4 + 10 + 12;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusL);
    return InkWell(
      onTap: () => openBundle(context, bundle.bundleId),
      borderRadius: radius,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: radius,
          border: AppDecorations.cardBorder(
            width: 1.5,
            lightColor: AppColors.primary.withValues(alpha: 0.25),
          ),
          boxShadow: AppDecorations.cardShadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CourseCoverImage(
                    url: bundle.imageUrl,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: BundleCountBadge(count: bundle.courseCount),
                ),
                if (bundle.isPurchased)
                  const Positioned(top: 8, right: 8, child: _PurchasedPill()),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bundle.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            StorePriceRow(
              price: bundle.price,
              mrp: bundle.actualPrice,
              discountPercent: bundle.discountPercent,
            ),
            const SizedBox(height: 4),
            _SubLine(bundle: bundle),
          ],
        ),
      ),
    );
  }
}

/// "Your price ₹3,200" when it differs, else "Save ₹1,200", else the
/// access line — one line, so the tile height stays fixed.
class _SubLine extends StatelessWidget {
  final BundleCard bundle;

  const _SubLine({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyTextSmallMedium;
    final (text, color) = bundle.hasPersonalPrice
        ? (
            'Your price ${StoreFormat.money(bundle.yourPrice)}',
            AppColors.primary,
          )
        : bundle.savings > 0
        ? ('Save ${StoreFormat.money(bundle.savings)}', AppColors.success)
        : (bundle.accessText, AppColors.mutedTextPrimary);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

/// "3 courses" chip over the cover.
class BundleCountBadge extends StatelessWidget {
  final int count;

  const BundleCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_rounded, size: 13, color: AppColors.onPrimary),
          const SizedBox(width: 4),
          Text(
            count == 1 ? '1 course' : '$count courses',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasedPill extends StatelessWidget {
  const _PurchasedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        'Purchased',
        style: AppTypography.bodyTextXtraSmallBold.copyWith(
          color: AppColors.alwaysWhite,
        ),
      ),
    );
  }
}
