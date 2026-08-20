import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:nexora/core/widgets/rating_and_review_row_widget.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/course_list_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/course_filter_sheet.dart';
import 'package:nexora/features/courses/presentation/widgets/view_demo_buy_now_row_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

/// Course List Screen — shows courses scoped to either a tile or a category.
///
/// Pass [tileId] OR [categoryId]. [title] is the display title for the AppBar.
class CourseListPage extends StatefulWidget {
  final int? tileId;
  final int? categoryId;
  final String title;

  const CourseListPage({
    super.key,
    this.tileId,
    this.categoryId,
    this.title = 'Courses',
  }) : assert(
         tileId != null || categoryId != null,
         'Provide either tileId or categoryId',
       );

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final ScrollController _scrollController = ScrollController();
  late final CourseListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<CourseListCubit>();
    _scrollController.addListener(_onScroll);

    if (widget.tileId != null) {
      _cubit.loadByTile(widget.tileId!);
    } else {
      _cubit.loadByCategory(widget.categoryId!);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cubit.loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: CustomAppBar(
          title: widget.title,
          centerTitle: true,
          titleColor: AppColors.textPrimary,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search + filter row (taps through to dedicated search page)
              Padding(
                padding: Screen.getPadding(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchBar(
                        onTap: () => context.push(AppRoutes.courseSearch),
                      ),
                    ),
                    SizedBox(width: Screen.getHorizontalSize(10)),
                    _FilterButton(
                      onTap: () async {
                        final filters = await CourseFilterSheet.show(context);
                        if (filters == null || !context.mounted) return;
                        // filters.categoryId and filters.typeId are now
                        // available for server-side filtering. Wire into
                        // the list cubit when the backend supports it.
                        // For now we log the selection so it's visible
                        // during development.
                        debugPrint(
                          '[CourseFilters] category=${filters.categoryId}'
                          ' (${filters.categoryName})'
                          ', type=${filters.typeId}'
                          ' (${filters.typeName})'
                          ', level=${filters.level}'
                          ', sortBy=${filters.sortBy}',
                        );
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: BlocBuilder<CourseListCubit, CourseListState>(
                  builder: (context, state) {
                    return state.maybeWhen(
                      loading: () => const _CourseListShimmer(),
                      loaded: (courses, hasMoreData, currentPage, isLoadingMore) =>
                          _buildList(context, courses, isLoadingMore),
                      error: (message) => _ErrorView(
                        message: message,
                        onRetry: () {
                          if (widget.tileId != null) {
                            _cubit.loadByTile(widget.tileId!);
                          } else {
                            _cubit.loadByCategory(widget.categoryId!);
                          }
                        },
                      ),
                      orElse: () => const _CourseListShimmer(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<CourseSummary> courses,
    bool isLoadingMore,
  ) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              "No courses available yet",
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      );
    }
    final count = courses.length + (isLoadingMore ? 1 : 0);
    return ListView.separated(
      controller: _scrollController,
      padding: Screen.getPadding(horizontal: 20, vertical: 16),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: Screen.getVerticalSize(12)),
      itemBuilder: (context, index) {
        if (index == courses.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final course = courses[index];
        return _CourseListCard(
          course: course,
          onTap: () => context.push(
            '${AppRoutes.courseDetail}?courseId=${course.courseId}',
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search bar — tappable, navigates to the dedicated search page
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: Screen.getVerticalSize(46),
        padding: Screen.getPadding(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Find your courses here",
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.grey400,
                  fontSize: Screen.getFontSize(14),
                ),
              ),
            ),
            Icon(
              Icons.search,
              color: AppColors.mutedTextPrimary,
              size: Screen.getSize(20),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter button — neumorphism circular button (Figma spec)
//   42x42, white fill, 1px #AFAAFF gradient border,
//   two inner shadows for the soft pressed-in look.
// ─────────────────────────────────────────────────────────────
class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FilterButton({required this.onTap});

  // Figma tokens — kept here so the design stays self-documenting.
  static const double _size = 42;
  static const Color _borderColor = Color(0xFFAFAAFF);
  // Painted over the fill, so both tones have to follow it.
  static Color get _innerShadowDark =>
      AppColors.isDark ? AppColors.grey100 : const Color(0xFFD9D6FF);
  static const Color _innerShadowLight = Color(
    0xFFF0EFFF,
  ); // bottom inner shadow

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(_size);
    final radius = BorderRadius.circular(size / 2);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: _borderColor.withValues(alpha: 0.15),
        highlightColor: _borderColor.withValues(alpha: 0.08),
        child: Container(
          width: size,
          height: size,
          // Linear-gradient border (15% → 100% → 15%) painted via the
          // gradient + an inner white fill. Padding of 1px gives the
          // border its visible thickness.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _borderColor.withValues(alpha: 0.15),
                _borderColor,
                _borderColor.withValues(alpha: 0.15),
              ],
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: ClipOval(
            child: CustomPaint(
              // Inner shadows are painted on TOP of the white fill so
              // they actually look pressed in.
              foregroundPainter: _DualInnerShadowPainter(
                topShadowColor: _innerShadowDark,
                topOffset: const Offset(0, 4),
                topBlur: 6,
                bottomShadowColor: _innerShadowLight,
                bottomOffset: const Offset(0, -3),
                bottomBlur: 6,
                borderRadius: radius,
              ),
              child: Container(
                color: AppColors.white,
                alignment: Alignment.center,
                child: Image.asset(
                  AppImages.sortIconColored,
                  height: Screen.getSize(18),
                  width: Screen.getSize(18),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacks two [InnerShadowPainter] passes so the button gets the dual
/// neumorphic glow (top dark, bottom light) in a single foreground paint.
class _DualInnerShadowPainter extends CustomPainter {
  final Color topShadowColor;
  final Offset topOffset;
  final double topBlur;
  final Color bottomShadowColor;
  final Offset bottomOffset;
  final double bottomBlur;
  final BorderRadius borderRadius;

  _DualInnerShadowPainter({
    required this.topShadowColor,
    required this.topOffset,
    required this.topBlur,
    required this.bottomShadowColor,
    required this.bottomOffset,
    required this.bottomBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    InnerShadowPainter(
      color: topShadowColor,
      blurRadius: topBlur,
      offset: topOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
    InnerShadowPainter(
      color: bottomShadowColor,
      blurRadius: bottomBlur,
      offset: bottomOffset,
      borderRadius: borderRadius,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_DualInnerShadowPainter old) =>
      topShadowColor != old.topShadowColor ||
      topOffset != old.topOffset ||
      topBlur != old.topBlur ||
      bottomShadowColor != old.bottomShadowColor ||
      bottomOffset != old.bottomOffset ||
      bottomBlur != old.bottomBlur ||
      borderRadius != old.borderRadius;
}

class _CourseListCard extends StatelessWidget {
  final CourseSummary course;
  final VoidCallback? onTap;

  const _CourseListCard({required this.course, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomNetworkImage(
            url: course.courseImageUrl,
            height: Screen.getVerticalSize(160),
            width: double.infinity,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            errorWidget: Container(
              height: Screen.getVerticalSize(160),
              color: AppColors.grey100,
              child: Center(
                child: Icon(Icons.image_outlined, color: AppColors.grey300),
              ),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          Text(
            course.courseTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(6)),
          RatingAndReviewRowWidget(
            rating: course.rating.toString(),
            reviewCount: Utils.formatReviewCount(course.totalReviewsCounts),
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          ViewDemoBuyNowRow(
            courseId: course.courseId,
            showViewDetails: true,
            showViewDemo: false,
            showBuyNow: course.isPurchased == false,
            // Flip the local purchased flag so the row's "Buy Now"
            // disappears without a full refetch of the list.
            onPurchased: () => context
                .read<CourseListCubit>()
                .updatePurchasedStatus(course.courseId, true),
          ),

          // Row(
          //   children: [
          //     Expanded(
          //       child: CustomOutlinedActionButton(
          //         isFormFilled: true,
          //         name: "View Details",
          //         buttonHeight: Screen.getVerticalSize(40),
          //         onTap: (startLoading, stopLoading, btnState) {
          //           onTap?.call();
          //         },
          //       ),
          //     ),
          //     if (course.isPurchased == false) ...[
          //       SizedBox(width: Screen.getHorizontalSize(10)),
          //       Expanded(
          //         child: CustomActionButton(
          //           name: "Buy Now",
          //           isFormFilled: true,
          //           buttonHeight: Screen.getVerticalSize(40),
          //           onTap: (startLoading, stopLoading, btnState) {
          //             // Todo: Implement purchase
          //           },
          //         ),
          //       ),
          //     ],
          //   ],
          // ),
        ],
      ),
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

// ─────────────────────────────────────────────────────────────
// Course List Shimmer — placeholder while courses load
// ─────────────────────────────────────────────────────────────

/// Renders a column of [_CourseListCardShimmer] rows. Wrapped in a single
/// [Shimmer.fromColors] so the highlight sweeps across the whole list in
/// one coherent pass instead of every card animating independently.
class _CourseListShimmer extends StatelessWidget {
  const _CourseListShimmer();

  static const _placeholderCount = 4;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 15, vertical: 16),
        itemCount: _placeholderCount,
        separatorBuilder: (_, __) =>
            SizedBox(height: Screen.getVerticalSize(12)),
        itemBuilder: (_, __) => const _CourseListCardShimmer(),
      ),
    );
  }
}

/// Mirrors the layout of [_CourseListCard]: hero image, title bar,
/// rating bar, and two action-button placeholders.
class _CourseListCardShimmer extends StatelessWidget {
  const _CourseListCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Transparent fill so the white placeholder bars inside actually
        // contrast with the card. Only the border defines the card shape.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          width: 1,
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course image placeholder
          Container(
            height: Screen.getVerticalSize(160),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(12)),

          // Title (two lines)
          _Bar(width: double.infinity, height: 14),
          SizedBox(height: Screen.getVerticalSize(6)),
          _Bar(width: Screen.getHorizontalSize(180), height: 14),
          SizedBox(height: Screen.getVerticalSize(10)),

          // Rating row
          _Bar(width: Screen.getHorizontalSize(140), height: 12),
          SizedBox(height: Screen.getVerticalSize(14)),

          // Action buttons (View Details + Buy Now)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: Screen.getVerticalSize(40),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(10)),
              Expanded(
                child: Container(
                  height: Screen.getVerticalSize(40),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  const _Bar({required this.width, required this.height});

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
