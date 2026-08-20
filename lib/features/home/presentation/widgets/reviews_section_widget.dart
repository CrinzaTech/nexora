import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:nexora/core/widgets/star_rating.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReviewsSectionWidget extends StatelessWidget {
  final List<LearnerReview> reviews;

  const ReviewsSectionWidget({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    final rh = ResponsiveHelper.of(context);
    // A little extra vertical room on iPad/fold/tablet so the capped-but-
    // still-larger name/title text isn't as tight against the review copy.
    final cardsHeight =
        Screen.getVerticalSize(170) + (rh.isLargeScreen ? 30 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Text(
            "What Other Learners Say",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h5SemiBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: Screen.getFontSizeCapped(20),
            ),
          ),
        ),

        SizedBox(height: Screen.getVerticalSize(16)),

        SizedBox(
          height: cardsHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: Screen.getPadding(horizontal: 20),
            itemCount: reviews.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: Screen.getHorizontalSize(15)),
            itemBuilder: (context, index) {
              return _ReviewCard(review: reviews[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final LearnerReview review;

  const _ReviewCard({required this.review});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusL);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.primary.withValues(alpha: 0.47);
    final innerColor = AppColors.primary.withValues(alpha: 0.12);
    final rh = ResponsiveHelper.of(context);
    // A little wider on iPad/fold/tablet to match the taller card above.
    final cardWidth =
        Screen.getHorizontalSize(275) + (rh.isLargeScreen ? 35 : 0);

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.10),
            blurRadius: 9,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: radius,
              border: GradientBorder(
                gradient: LinearGradient(
                  colors: [borderLow, borderMid, borderLow],
                ),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                onTap: () => context.push(
                  '${AppRoutes.courseDetail}?courseId=${review.courseId}',
                ),
                borderRadius: radius,
                splashColor: AppColors.primary.withValues(alpha: 0.10),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: Screen.getPadding(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name + stars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _Avatar(
                            imageUrl: review.profileImageUrl,
                            initials: _initials(review.learnerName),
                          ),
                          SizedBox(width: Screen.getHorizontalSize(12)),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.learnerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyTextLargeSemiBold
                                      .copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: Screen.getFontSizeCapped(15),
                                      ),
                                ),
                                SizedBox(height: Screen.getVerticalSize(4)),
                                StarRating(
                                  rating: review.courseRating,
                                  size: Screen.getSize(16),
                                  spacing: 1,
                                  emptyColor: AppColors.warning.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Course title — only renders when the backend ships it.
                      if (review.courseTitle.isNotEmpty) ...[
                        SizedBox(height: Screen.getVerticalSize(10)),
                        Text(
                          review.courseTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            // color: AppColors.primary,
                            fontSize: Screen.getFontSizeCapped(14),
                          ),
                        ),
                      ],

                      SizedBox(height: Screen.getVerticalSize(5)),

                      Expanded(
                        child: Text(
                          review.reviewMessage,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyTextMedium.copyWith(
                            color: AppColors.grey500,
                            fontSize: Screen.getFontSizeCapped(13),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: InnerShadowPainter(
                  color: innerColor,
                  blurRadius: 54,
                  offset: const Offset(0, 4),
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;
  final String initials;

  const _Avatar({required this.imageUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    // Uniform-scale (min of width/height factors), not getHorizontalSize —
    // this is a square element sitting in a height-constrained card, and on
    // near-square fold screens the width scale factor runs far ahead of the
    // height scale factor, which blew the avatar up past the card's height
    // budget and overflowed the review card's Column.
    final size = Screen.getSize(56);
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: CustomNetworkImage(
          url: imageUrl,
          width: size,
          height: size,
          errorWidget: _initialsAvatar(size),
        ),
      );
    }
    return _initialsAvatar(size);
  }

  Widget _initialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.alwaysWhite.withValues(alpha: 0.35),
            AppColors.alwaysWhite.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.alwaysWhite.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      // Wrap in a brand-gradient background so the frosted white layer
      // actually shows a colour rather than transparent.
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.alwaysWhite.withValues(alpha: 0.35),
                AppColors.alwaysWhite.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: AppTypography.h6SemiBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSize(16),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
