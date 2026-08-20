import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_outlined_action_button.dart';
import 'package:nexora/core/widgets/rating_and_review_row_widget.dart';
import 'package:nexora/core/widgets/scrolling_title.dart';
import 'package:nexora/core/widgets/star_rating.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/course_detail_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_reviews_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/module_card_widget.dart';
import 'package:nexora/features/courses/presentation/widgets/write_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shimmer/shimmer.dart';

import '../widgets/view_demo_buy_now_row_widget.dart';

/// Course Detail Screen — loads full course data from `/api/v1/course/{courseId}`.
class CourseDetailPage extends StatelessWidget {
  final int courseId;

  /// Optional title hint (e.g. [ctaName] from a banner tap). Shown in the
  /// AppBar immediately while the API is loading; replaced by the real
  /// [Course.courseTitle] once the data arrives.
  final String? courseTitle;

  const CourseDetailPage({super.key, required this.courseId, this.courseTitle});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CourseDetailCubit>()..load(courseId)),
        BlocProvider(create: (_) => sl<CourseReviewsCubit>()..load(courseId)),
      ],
      child: _CourseDetailView(courseId: courseId, courseTitle: courseTitle),
    );
  }
}

class _CourseDetailView extends StatefulWidget {
  final int courseId;
  final String? courseTitle;

  const _CourseDetailView({required this.courseId, this.courseTitle});

  @override
  State<_CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<_CourseDetailView>
    with TickerProviderStateMixin {
  /// Tab index used by both the body's [TabBar] and the Scaffold's
  /// bottom bar (so the bar can hide / show buttons based on the
  /// currently-selected tab).
  late final TabController _tabController;

  /// Index of the Reviews tab — kept as a constant so the bottom-bar
  /// logic stays readable.
  static const int _reviewsTabIndex = 2;

  /// The title shown in the AppBar. Initialised from the [widget.courseTitle]
  /// hint (if provided) so something meaningful shows immediately; updated
  /// to the authoritative [Course.courseTitle] once the API responds.
  late String _displayTitle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displayTitle =
        (widget.courseTitle != null && widget.courseTitle!.isNotEmpty)
        ? widget.courseTitle!
        : 'Course Details';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return Scaffold(
      appBar: CustomAppBar(
        title: _displayTitle,
        centerTitle: true,
        titleColor: AppColors.textPrimary,
      ),
      bottomNavigationBar: BlocBuilder<CourseDetailCubit, CourseDetailState>(
        // Action bar is gated on the course payload — and on the active
        // tab when the user has already purchased.
        builder: (context, state) => state.maybeWhen(
          loaded: (course) => AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => _CourseDetailBottomBar(
              course: course,
              isOnReviewsTab: _tabController.index == _reviewsTabIndex,
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: BlocListener<CourseDetailCubit, CourseDetailState>(
        // Update the AppBar title as soon as the API response arrives.
        listener: (context, state) {
          state.maybeWhen(
            loaded: (course) {
              if (course.courseTitle.isNotEmpty &&
                  course.courseTitle != _displayTitle) {
                setState(() => _displayTitle = course.courseTitle);
              }
            },
            orElse: () {},
          );
        },
        child: BlocBuilder<CourseDetailCubit, CourseDetailState>(
          builder: (context, state) {
            return state.maybeWhen(
              loading: () => const _CourseDetailShimmer(),
              loaded: (course) => _CourseDetailBody(
                course: course,
                tabController: _tabController,
              ),
              error: (message) => _ErrorView(
                message: message,
                onRetry: () =>
                    context.read<CourseDetailCubit>().load(widget.courseId),
              ),
              orElse: () => const _CourseDetailShimmer(),
            );
          },
        ),
      ),
    );
  }
}

class _CourseDetailBody extends StatelessWidget {
  final Course course;
  final TabController tabController;

  const _CourseDetailBody({required this.course, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(15),
                vertical: Screen.getVerticalSize(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomNetworkImage(
                    url: course.courseImageUrl,
                    width: double.infinity,
                    height: rh.isLargeScreen ? Screen.getVerticalSize(280) : Screen.getVerticalSize(210),
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    errorWidget: Container(
                      height: rh.isLargeScreen ? Screen.getVerticalSize(280) : Screen.getVerticalSize(210),
                    color: AppColors.grey100,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.grey300,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(20)),
                ScrollingTitle(
                  text: course.courseTitle,
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    // Decrease the title size by 1.5x to balance the global scaling
                    fontSize: rh.isLargeScreen ? (rh.cappedFontSize(20) / 1.5) : null,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(5)),
                RatingAndReviewRowWidget(
                  rating: course.totalRating.toString(),
                  reviewCount: Utils.formatReviewCount(
                    course.totalReviewsCounts,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(20)),
                _PriceRow(course: course),
                _ExpiryDetailsLine(course: course),
                SizedBox(height: Screen.getVerticalSize(20)),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            tabBar: TabBar(
              controller: tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.grey300,
              labelStyle: AppTypography.bodyTextSemiBold.copyWith(
                fontSize: rh.isLargeScreen ? rh.cappedFontSize(14) : null,
              ),
              unselectedLabelStyle: AppTypography.bodyTextMedium.copyWith(
                fontSize: rh.isLargeScreen ? rh.cappedFontSize(13) : Screen.getFontSize(13),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: AppColors.primary,
              indicatorWeight: 1,
              tabs: const [
                Tab(text: "About"),
                Tab(text: "Content"),
                Tab(text: "Reviews"),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _AboutTab(course: course),
          _CurriculumTab(course: course),
          _ReviewsTab(courseId: course.courseId),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Course course;

  const _PriceRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    // Once the course is purchased, the price block is replaced by a
    // "Purchased" pill — the user already paid and the bottom bar handles
    // resume/continue actions.
    if (course.isPurchased) return const _PurchasedBadge();
    // Multi-tier courses defer pricing to the "Choose Plan" sheet —
    // showing just `primaryPricing` up top would mislead the user
    // into thinking that's the only option. The CTA below renders
    // as "Choose Plan" in this case.
    if (course.pricing.length > 1) return const SizedBox.shrink();
    final finalP = course.finalPrice ?? course.originalPrice;
    if (finalP == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Final / payable price \u2014 what the user actually pays. Never
        // struck through. Falls back to originalPrice when the backend
        // hasn't shipped a separate discounted value, so a single full-
        // price course still renders as one bold number.
        Text(
          "\u20B9 ${Utils.formatPrice(finalP.toDouble())}",
          style: AppTypography.h5SemiBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: rh.isLargeScreen ? rh.cappedFontSize(20) : null,
          ),
        ),
        // MSRP \u2014 rendered struck through only when there's an actual
        // discount (originalPrice is set AND strictly larger than the
        // final price). Without this guard the same number would print
        // twice when no discount applies.
        if (course.hasDiscount) ...[
          SizedBox(width: Screen.getHorizontalSize(10)),
          Text(
            "\u20B9 ${Utils.formatPrice(course.originalPrice!.toDouble())}",
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.mutedTextPrimary,
              fontSize: rh.isLargeScreen ? rh.cappedFontSize(16) : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// Informational line under the price block — shows the backend's
/// human-readable access window (e.g. "Access for 2 months",
/// "109567 days remaining"). Rendered for every state of the course
/// (purchased / not, single tier / multi tier) so the user always
/// sees the duration their purchase grants; the only thing that
/// suppresses it is the backend shipping a null / empty string.
class _ExpiryDetailsLine extends StatelessWidget {
  final Course course;

  const _ExpiryDetailsLine({required this.course});

  @override
  Widget build(BuildContext context) {
    final raw = course.expiryDetails?.trim();
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: Screen.getVerticalSize(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: Screen.getSize(16),
            color: AppColors.mutedTextPrimary,
          ),
          SizedBox(width: Screen.getHorizontalSize(6)),
          Flexible(
            child: Text(
              raw,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: ResponsiveHelper.of(context).isLargeScreen 
                    ? ResponsiveHelper.of(context).cappedFontSize(14) 
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasedBadge extends StatelessWidget {
  const _PurchasedBadge();

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return Container(
      padding: Screen.getPadding(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: rh.isLargeScreen ? Screen.getSize(18) * rh.fontScaleFactor : Screen.getSize(18),
            color: AppColors.successDark,
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Text(
            'Purchased',
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.successDark,
              fontSize: rh.isLargeScreen ? rh.cappedFontSize(16) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final rh = ResponsiveHelper.of(context);
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(
        horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(15),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _AboutTab extends StatelessWidget {
  final Course course;

  const _AboutTab({required this.course});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final description = course.description ?? '';
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(15),
        vertical: Screen.getVerticalSize(20)
      ),
      children: [
        Text(
          "About this course",
          style: AppTypography.h6SemiBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: rh.isLargeScreen ? rh.cappedFontSize(18) : null,
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(10)),
        if (description.isEmpty)
          Text(
            "No description available.",
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: rh.isLargeScreen ? rh.cappedFontSize(16) : null,
            ),
          )
        else
          MarkdownBody(
            data: description,
            // shrinkWrap so the description sizes itself inside the parent
            // ListView; selectable so users can copy snippets out of the
            // course outline.
            shrinkWrap: true,
            selectable: true,
            styleSheet: _descriptionMarkdownStyle(context, rh),
          ),
        SizedBox(height: Screen.getVerticalSize(80)),
      ],
    );
  }

  /// Maps the app's typography tokens onto flutter_markdown's stylesheet so
  /// rendered headings/lists/code feel native to the design system.
  MarkdownStyleSheet _descriptionMarkdownStyle(BuildContext context, ResponsiveHelper rh) {
    final body = AppTypography.bodyTextLargeMedium.copyWith(
      height: 1.5,
      fontWeight: FontWeight.w300,
      color: AppColors.textSecondary,
      fontSize: rh.isLargeScreen ? rh.cappedFontSize(16) : null,
    );
    return MarkdownStyleSheet(
      p: body,
      a: body.copyWith(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
      ),
      h1: AppTypography.h4SemiBold.copyWith(color: AppColors.textPrimary),
      h2: AppTypography.h5SemiBold.copyWith(color: AppColors.textPrimary),
      h3: AppTypography.h6SemiBold.copyWith(color: AppColors.textPrimary),
      h4: AppTypography.bodyTextLargeSemiBold.copyWith(
        color: AppColors.textPrimary,
      ),
      h5: AppTypography.bodyTextSemiBold.copyWith(color: AppColors.textPrimary),
      h6: AppTypography.bodyTextSemiBold.copyWith(color: AppColors.textPrimary),
      strong: body.copyWith(fontWeight: FontWeight.w600),
      em: body.copyWith(fontStyle: FontStyle.italic),
      listBullet: body,
      blockquote: body.copyWith(color: AppColors.mutedTextPrimary),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      code: body.copyWith(
        fontFamily: 'monospace',
        backgroundColor: AppColors.grey100,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
    );
  }
}

class _CurriculumTab extends StatelessWidget {
  final Course course;

  const _CurriculumTab({required this.course});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final content = course.courseNodes?.content ?? const <CourseContent>[];
    if (content.isEmpty) {
      return Center(
        child: Text(
          "No curriculum available yet",
          style: AppTypography.bodyTextLargeMedium.copyWith(
            color: AppColors.mutedTextPrimary,
            fontSize: rh.isLargeScreen ? rh.cappedFontSize(16) : null,
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(15),
        vertical: Screen.getVerticalSize(20)
      ),
      children: [
        ...content.map(
          (node) => ModuleCard(
            module: node,
            courseId: course.courseId,
            coursePurchasedId: course.coursePurchasedId,
            activateWatermark: course.courseNodes?.activateWatermark ?? false,
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(80)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(16)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                "Retry",
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reviews tab — loads reviews from `/api/v1/course/{courseId}/reviews`
/// via [CourseReviewsCubit].
class _ReviewsTab extends StatelessWidget {
  final int courseId;

  const _ReviewsTab({required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseReviewsCubit, CourseReviewsState>(
      builder: (context, state) {
        return state.maybeWhen(
          loading: () => const _ReviewsShimmer(),
          submitting: () => const _ReviewsShimmer(),
          loaded: (reviews) {
            if (reviews.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 64,
                      color: AppColors.grey300,
                    ),
                    SizedBox(height: Screen.getVerticalSize(12)),
                    Text(
                      "No reviews yet",
                      style: AppTypography.bodyTextLargeMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.of(context).isLargeScreen 
                    ? ResponsiveHelper.of(context).horizontalPadding 
                    : Screen.getHorizontalSize(15), 
                vertical: Screen.getVerticalSize(20)
              ),
              itemCount: reviews.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: Screen.getVerticalSize(12)),
              itemBuilder: (_, index) => _ReviewCard(review: reviews[index]),
            );
          },
          error: (message) => _ErrorView(
            message: message,
            onRetry: () => context.read<CourseReviewsCubit>().load(courseId),
          ),
          orElse: () => const _ReviewsShimmer(),
        );
      },
    );
  }
}

/// Sticky bottom action bar — "Write a Review" + "Enroll Now".
///
/// Lives at the [Scaffold.bottomNavigationBar] level so both buttons stay
/// visible across all three tabs (About, Curriculum, Reviews).
/// Sticky bottom action bar — content depends on (`isPurchased`, active
/// tab):
/// - **Not purchased** (any tab) → `View Demo` + `Buy Now`.
/// - **Purchased + Reviews tab**  → `Write a Review`.
/// - **Purchased + other tab**    → bar is hidden entirely.
class _CourseDetailBottomBar extends StatelessWidget {
  final Course course;
  final bool isOnReviewsTab;

  const _CourseDetailBottomBar({
    required this.course,
    required this.isOnReviewsTab,
  });

  @override
  Widget build(BuildContext context) {
    // Purchased users only see the bar on the Reviews tab.
    if (course.isPurchased && !isOnReviewsTab) return const SizedBox.shrink();

    final rh = ResponsiveHelper.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(16), 
            vertical: Screen.getVerticalSize(12)
          ),
          child: course.isPurchased
              ? _WriteReviewButton(courseId: course.courseId)
              : ViewDemoBuyNowRow(
                  courseId: course.courseId,
                  // Hand the already-loaded tier list down so the CTA
                  // can render as "Choose Plan" up-front when the
                  // course has more than one buyable plan, instead of
                  // the user discovering that only on tap.
                  tiers: course.pricing,
                  showBuyNow: true,
                  showViewDemo: false,
                  showViewDetails: false,
                  // Refetch the detail so isPurchased flips and the price
                  // block becomes the "Purchased" badge.
                  onPurchased: () =>
                      context.read<CourseDetailCubit>().load(course.courseId),
                ),
        ),
      ),
    );
  }
}

/// Single full-width "Write a Review" pill — shown on the Reviews tab for
/// purchased courses.
class _WriteReviewButton extends StatelessWidget {
  final int courseId;

  const _WriteReviewButton({required this.courseId});

  @override
  Widget build(BuildContext context) {
    return CustomOutlinedActionButton(
      isFormFilled: true,
      name: 'Write a Review',
      buttonHeight: 50,
      onTap: (_, __, ___) => WriteReviewDialog.show(context, courseId),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final CourseReview review;

  const _ReviewCard({required this.review});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return "${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}, ${d.year}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          width: 1.5,
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewAvatar(
                imageUrl: review.profileImageUrl,
                initials: review.initials,
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.learnerName ?? 'Anonymous',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(4)),
                    StarRating(
                      rating: review.courseRating,
                      size: Screen.getSize(16),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(review.reviewDate),
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: Screen.getFontSize(12),
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(12)),
          Text(
            review.reviewMessage,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;

  const _ReviewAvatar({required this.imageUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(44);
    if (imageUrl != null && imageUrl!.isNotEmpty) {
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
        color: AppColors.primary,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.bodyTextSemiBold.copyWith(
          color: AppColors.alwaysWhite,
          fontSize: Screen.getFontSize(14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reviews Shimmer — placeholder list while reviews load
// ─────────────────────────────────────────────────────────────
class _ReviewsShimmer extends StatelessWidget {
  const _ReviewsShimmer();

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: rh.isLargeScreen ? rh.horizontalPadding : Screen.getHorizontalSize(15), 
        vertical: Screen.getVerticalSize(20)
      ),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: Screen.getVerticalSize(12)),
      itemBuilder: (_, __) => const _ReviewCardShimmer(),
    );
  }
}

class _ReviewCardShimmer extends StatelessWidget {
  const _ReviewCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          width: 1.5,
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.grey200.withValues(alpha: 0.6),
        highlightColor: AppColors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar placeholder
                Container(
                  width: Screen.getSize(44),
                  height: Screen.getSize(44),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(12)),
                // Name + stars
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBar(
                        width: Screen.getHorizontalSize(120),
                        height: 14,
                      ),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      _ShimmerBar(
                        width: Screen.getHorizontalSize(90),
                        height: 12,
                      ),
                    ],
                  ),
                ),
                // Date placeholder
                _ShimmerBar(width: Screen.getHorizontalSize(60), height: 10),
              ],
            ),
            SizedBox(height: Screen.getVerticalSize(14)),
            // Message lines
            _ShimmerBar(width: double.infinity, height: 10),
            SizedBox(height: Screen.getVerticalSize(6)),
            _ShimmerBar(width: double.infinity, height: 10),
            SizedBox(height: Screen.getVerticalSize(6)),
            _ShimmerBar(width: Screen.getHorizontalSize(180), height: 10),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Course Detail Shimmer — placeholder while the course payload loads
// ─────────────────────────────────────────────────────────────

/// Mirrors the layout of [_CourseDetailBody]: hero image, title, rating,
/// price, tab strip, then a few module-card placeholders. Wrapped in a
/// single [Shimmer.fromColors] so the highlight sweeps across the whole
/// page in one pass instead of every block animating independently.
class _CourseDetailShimmer extends StatelessWidget {
  const _CourseDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 15, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            Container(
              width: Screen.width,
              height: Screen.getVerticalSize(210),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(20)),

            // Title
            _ShimmerBar(width: Screen.getHorizontalSize(220), height: 22),
            SizedBox(height: Screen.getVerticalSize(10)),

            // Rating row
            _ShimmerBar(width: Screen.getHorizontalSize(140), height: 14),
            SizedBox(height: Screen.getVerticalSize(20)),

            // Price row (final + original strikethrough placeholders)
            Row(
              children: [
                _ShimmerBar(width: Screen.getHorizontalSize(90), height: 22),
                SizedBox(width: Screen.getHorizontalSize(10)),
                _ShimmerBar(width: Screen.getHorizontalSize(60), height: 16),
              ],
            ),
            SizedBox(height: Screen.getVerticalSize(24)),

            // Tab strip placeholder (3 tabs)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (_) => _ShimmerBar(
                  width: Screen.getHorizontalSize(80),
                  height: 14,
                ),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(28)),

            // A few module-card placeholders below the tab strip
            ...List.generate(
              3,
              (_) => Padding(
                padding: EdgeInsets.only(bottom: Screen.getVerticalSize(10)),
                child: const _ModuleCardShimmer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single module-row placeholder used inside [_CourseDetailShimmer].
class _ModuleCardShimmer extends StatelessWidget {
  const _ModuleCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          width: 1.5,
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Leading icon block
          Container(
            width: Screen.getVerticalSize(40),
            height: Screen.getVerticalSize(40),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(12)),
          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBar(width: Screen.getHorizontalSize(160), height: 14),
                SizedBox(height: Screen.getVerticalSize(6)),
                _ShimmerBar(width: Screen.getHorizontalSize(80), height: 12),
              ],
            ),
          ),
          // Trailing chevron
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
