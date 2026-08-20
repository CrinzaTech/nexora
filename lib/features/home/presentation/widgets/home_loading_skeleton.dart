import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Loading skeleton for [HomePage].
///
/// Mirrors the loaded view's new shape: coloured AppBar-style header
/// band on top, white rounded body card below. The header placeholders
/// shimmer against the primary band, the body placeholders shimmer
/// against the white card. Structural surfaces (the coloured band and
/// the white card) sit *outside* the shimmer scope so they render
/// exactly like the loaded view instead of pulsing.
class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same coloured band as the loaded view → no jump on swap.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: _ShimmerScope(child: const _HeaderSkeleton()),
            ),
          ),
          // White rounded body card — same surface treatment as the
          // loaded view (single soft shadow), so the swap from
          // skeleton → real content doesn't flicker.
          Container(
            width: Screen.width,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusXXL),
                topRight: Radius.circular(AppSizes.radiusXXL),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: _ShimmerScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: Screen.getVerticalSize(20)),
                  const _BannerSkeleton(),
                  SizedBox(height: Screen.getVerticalSize(25)),
                  const _CategorySkeleton(),
                  SizedBox(height: Screen.getVerticalSize(25)),
                  const _FeaturedCoursesSkeleton(),
                  SizedBox(height: Screen.getVerticalSize(25)),
                  const _ReviewsSkeleton(),
                  SizedBox(height: Screen.getVerticalSize(40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shimmer scope — same palette + cadence everywhere, kept in one place
// so all three regions read identically.
// ─────────────────────────────────────────────────────────────

class _ShimmerScope extends StatelessWidget {
  final Widget child;

  const _ShimmerScope({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.55),
      highlightColor: AppColors.white,
      period: const Duration(milliseconds: 1600),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section skeletons
// ─────────────────────────────────────────────────────────────

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    // Same top padding as the loaded header — the parent SafeArea is
    // already inset for the status bar, so a 14 px lead matches the
    // loaded view's `_buildHeader` padding exactly.
    return Padding(
      padding: Screen.getPadding(left: 20, right: 20, top: 14, bottom: 14),
      child: Row(
        children: [
          const _SkeletonCircle(size: 56),
          SizedBox(width: Screen.getHorizontalSize(12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SkeletonBox(width: 70, height: 12),
              SizedBox(height: Screen.getVerticalSize(8)),
              const _SkeletonBox(width: 140, height: 18),
            ],
          ),
          const Spacer(),
          const _SkeletonCircle(size: 38),
          SizedBox(width: Screen.getHorizontalSize(8)),
          const _SkeletonCircle(size: 38),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ContinueLearningSkeleton extends StatelessWidget {
  const _ContinueLearningSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: const _SkeletonBox(width: 160, height: 20),
        ),
        SizedBox(height: Screen.getVerticalSize(12)),
        SizedBox(
          height: Screen.getVerticalSize(220),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: Screen.getPadding(horizontal: 20),
            itemCount: 3,
            separatorBuilder: (_, __) =>
                SizedBox(width: Screen.getHorizontalSize(12)),
            itemBuilder: (_, __) =>
                const _CourseCardSkeleton(cardWidth: 220, imageHeight: 120),
          ),
        ),
      ],
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 15),
          child: _SkeletonBox(
            height: Screen.getVerticalSize(185),
            width: double.infinity,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(10)),
        // Pager dots — one wider active dot, two short inactive ones.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SkeletonBox(
                width: i == 0 ? 28 : 6,
                height: 6,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    // Mirrors [CategorySection] — 2-column grid with 1.5 aspect ratio
    // tiles. Each tile has a 45x45 icon + a title bar to match the real
    // [_CategoryCard] layout.
    return Padding(
      padding: Screen.getPadding(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 180, height: 22),
          SizedBox(height: Screen.getVerticalSize(12)),
          GridView.builder(
            shrinkWrap: true,
            itemCount: 4,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 15,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (_, __) => Container(
              padding: Screen.getPadding(horizontal: 15),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SkeletonBox(
                    width: Screen.getHorizontalSize(45),
                    height: Screen.getVerticalSize(45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  SizedBox(width: Screen.getHorizontalSize(12)),
                  const Expanded(child: _SkeletonBox(height: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCoursesSkeleton extends StatelessWidget {
  const _FeaturedCoursesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SkeletonBox(width: 170, height: 18),
              _SkeletonBox(width: 50, height: 12),
            ],
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(12)),
        SizedBox(
          height: Screen.getVerticalSize(240),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: Screen.getPadding(horizontal: 20),
            itemCount: 2,
            separatorBuilder: (_, __) =>
                SizedBox(width: Screen.getHorizontalSize(12)),
            itemBuilder: (_, __) =>
                const _CourseCardSkeleton(cardWidth: 230, imageHeight: 150),
          ),
        ),
      ],
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: const _SkeletonBox(width: 180, height: 18),
        ),
        SizedBox(height: Screen.getVerticalSize(12)),
        SizedBox(
          height: Screen.getVerticalSize(140),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: Screen.getPadding(horizontal: 20),
            itemCount: 2,
            separatorBuilder: (_, __) =>
                SizedBox(width: Screen.getHorizontalSize(12)),
            itemBuilder: (_, __) => const _ReviewCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card skeletons (composed primitives)
// ─────────────────────────────────────────────────────────────

class _CourseCardSkeleton extends StatelessWidget {
  final double cardWidth;
  final double imageHeight;

  const _CourseCardSkeleton({
    required this.cardWidth,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Screen.getHorizontalSize(cardWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(
            width: double.infinity,
            height: Screen.getVerticalSize(imageHeight),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          const _SkeletonBox(width: 180, height: 14),
          SizedBox(height: Screen.getVerticalSize(8)),
          const _SkeletonBox(width: 110, height: 12),
        ],
      ),
    );
  }
}

class _ReviewCardSkeleton extends StatelessWidget {
  const _ReviewCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Screen.getHorizontalSize(280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonCircle(size: 40),
              SizedBox(width: Screen.getHorizontalSize(10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SkeletonBox(width: 110, height: 12),
                  SizedBox(height: Screen.getVerticalSize(6)),
                  const _SkeletonBox(width: 70, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(14)),
          const _SkeletonBox(width: double.infinity, height: 10),
          SizedBox(height: Screen.getVerticalSize(6)),
          _SkeletonBox(width: Screen.getHorizontalSize(220), height: 10),
          SizedBox(height: Screen.getVerticalSize(6)),
          _SkeletonBox(width: Screen.getHorizontalSize(180), height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Primitives — solid white shapes that the parent [Shimmer] remaps
// via its gradient blend, producing the pulse animation.
// ─────────────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
