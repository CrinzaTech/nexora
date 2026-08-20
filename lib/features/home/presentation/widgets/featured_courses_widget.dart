import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/rating_and_review_row_widget.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A unified course card data model used by [FeaturedCoursesWidget].
/// Both [NewCourse] and [TrendingCourse] share the same fields so we
/// map them into this lightweight struct at the call-site.
class CourseCardData {
  final int courseId;
  final String courseTitle;
  final String courseImageUrl;
  final double rating;
  final int totalReviewsCounts;

  const CourseCardData({
    required this.courseId,
    required this.courseTitle,
    required this.courseImageUrl,
    this.rating = 0.0,
    this.totalReviewsCounts = 0,
  });
}

/// A reusable horizontal course list widget.
///
/// Pass [title] for the section heading and set [showNewBadge] to `true`
/// when displaying "New Courses" — it renders an orange "NEW" pill badge
/// on each card image. Leave it `false` for Trending Courses (no badge).
class FeaturedCoursesWidget extends StatelessWidget {
  final String title;
  final List<CourseCardData> courses;

  /// When `true`, an orange "NEW" badge is shown on every card image.
  final bool showNewBadge;

  /// The route pushed when the user taps "View All".
  /// Defaults to [AppRoutes.catalog] (no sort/filter applied).
  final String? viewAllRoute;

  const FeaturedCoursesWidget({
    super.key,
    required this.title,
    required this.courses,
    this.showNewBadge = false,
    this.viewAllRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.h5SemiBold.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSizeCapped(20),
                ),
              ),
              InkWell(
                onTap: () => context.push(viewAllRoute ?? AppRoutes.catalog),
                child: Text(
                  "View All",
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: Screen.getFontSizeCapped(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: Screen.getVerticalSize(15)),

        // LayoutBuilder measures the available width so we can derive the
        // card height dynamically:
        //   imageHeight = cardWidth × (9/16)  ← 16:9 AspectRatio
        //   + textArea  = title (2 lines) + rating row + paddings
        // This gives the ListView a bounded cross-axis height while still
        // letting the image fill its frame at any upload size.
        LayoutBuilder(
          builder: (context, constraints) {
            final rh = ResponsiveHelper.of(context);
            final double cardWidth = rh.courseCardWidth;
            // Inner image width = card width − horizontal card padding (8 each side)
            final double imageWidth =
                cardWidth - Screen.getHorizontalSize(16).clamp(0.0, 16.0);
            final double imageHeight = imageWidth * (9 / 16);
            // Text area: top-pad(10) + image + gap(10) + title(~40) + gap(10)
            //            + rating(~24) + bottom-pad(10)
            // Heights are capped to prevent over-scaling on tablets.
            final double titleHeight =
                Screen.getFontSize(14) * 1.2 * 2; // 2 lines
            final double ratingHeight = Screen.getSize(24);
            final double gaps = Screen.getVerticalSize(10) * 2;
            final double padding = 20.0; // 10 top + 10 bottom
            final double cardHeight =
                imageHeight +
                titleHeight +
                ratingHeight +
                gaps +
                padding +
                15.0; // 15px safety buffer

            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: rh.horizontalPadding),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  return _CourseCard(
                    course: courses[index],
                    showNewBadge: showNewBadge,
                    cardWidth: cardWidth,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseCardData course;
  final bool showNewBadge;
  final double cardWidth;

  const _CourseCard({
    required this.course,
    required this.showNewBadge,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push('${AppRoutes.courseDetail}?courseId=${course.courseId}'),
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: AppDecorations.cardBorder(
            width: 1.5,
            lightColor: AppColors.primary.withValues(alpha: 0.25),
          ),
          boxShadow: AppDecorations.cardShadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Course image + optional NEW badge ──────────────────
            Stack(
              children: [
                // AspectRatio(16:9) so the image fills its frame fully
                // regardless of the original upload dimensions.
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CustomNetworkImage(
                    url: course.courseImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    errorWidget: Container(
                      color: AppColors.grey100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),

                // "NEW" badge — only shown when showNewBadge == true
                if (showNewBadge)
                  Positioned(top: 8, left: 8, child: const _AnimatedNewBadge()),
              ],
            ),

            SizedBox(height: Screen.getVerticalSize(10)),

            // ── Title + rating ─────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSize(14),
                    height: 1.2,
                  ),
                ),

                SizedBox(height: Screen.getVerticalSize(10)),

                RatingAndReviewRowWidget(
                  rating: course.rating.toString(),
                  reviewCount: Utils.formatReviewCount(
                    course.totalReviewsCounts,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A stateful widget that animates the "NEW" badge with a sweeping
/// glass shine effect for a premium, interactive look.
class _AnimatedNewBadge extends StatefulWidget {
  const _AnimatedNewBadge();

  @override
  State<_AnimatedNewBadge> createState() => _AnimatedNewBadgeState();
}

class _AnimatedNewBadgeState extends State<_AnimatedNewBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 3,
      ), // Increased to 3s for the double-sweep + pause cycle
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double shineCenter = -1.0; // Hidden completely off-screen by default

        // Double flash timing:
        // Sweep 1: 0% to 25% of the animation
        // Pause: 25% to 35%
        // Sweep 2: 35% to 60%
        // Long Pause: 60% to 100%
        if (_controller.value <= 0.25) {
          final progress = _controller.value / 0.25;
          shineCenter = -0.2 + (progress * 1.4);
        } else if (_controller.value >= 0.35 && _controller.value <= 0.60) {
          final progress = (_controller.value - 0.35) / 0.25;
          shineCenter = -0.2 + (progress * 1.4);
        }

        return Container(
          padding: Screen.getPadding(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                (shineCenter - 0.15).clamp(0.0, 1.0),
                shineCenter.clamp(0.0, 1.0),
                (shineCenter + 0.15).clamp(0.0, 1.0),
                1.0,
              ],
              colors: const [
                Color(0xFFFF8C00), // Base orange
                Color(0xFFFF9D2E), // Lift edge
                Color(0xFFFFFFFF), // Glass shine streak
                Color(0xFFFF8C00), // Base orange
                Color(0xFFE67E00), // Darker bottom edge
              ],
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(
              color: AppColors.alwaysWhite.withValues(alpha: 0.6), // Inner shine edge
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      // Pass the static content as a child to avoid rebuilding it every frame
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.alwaysWhite, size: 12),
          const SizedBox(width: 4),
          Text(
            'NEW',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(9),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
