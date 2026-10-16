import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/presentation/widgets/news_post_widgets.dart';
import 'package:flutter/material.dart';

/// One row of the News & Updates panel: thumbnail, chip, title, a two-line
/// preview, the time, and an unread dot.
class NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const NewsCard({super.key, required this.item, required this.onTap});

  static const double _thumb = 72;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final radius = BorderRadius.circular(AppSizes.radiusL);
    // A card of its own, so the content always has room inside the edge
    // the tap highlight draws. Unread posts get a primary-tinted rim.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppDecorations.cardShadow(),
      ),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: unread
              ? BorderSide(color: AppColors.primary.withValues(alpha: 0.35))
              : BorderSide(color: AppColors.black.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.hasImage) ...[
                  CustomNetworkImage(
                    url: item.imageUrl,
                    width: _thumb,
                    height: _thumb,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          NewsTypeChip(type: item.type),
                          const Spacer(),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextLargeSemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: Screen.getFontSizeCapped(15),
                          height: 1.3,
                        ),
                      ),
                      if (item.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyTextMedium.copyWith(
                            color: AppColors.mutedTextPrimary,
                            fontSize: Screen.getFontSizeCapped(13),
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        newsTimeLine(item),
                        style: AppTypography.bodyTextSmallMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                          fontSize: Screen.getFontSizeCapped(11),
                        ),
                      ),
                    ],
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
