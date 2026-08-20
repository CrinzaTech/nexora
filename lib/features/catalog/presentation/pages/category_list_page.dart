import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/presentation/bloc/course_filters_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

/// Categories List Screen
/// Dynamically fetches and displays all course categories in a premium grid.
/// Clicking a category navigates to the Catalog Page.
class CategoryListPage extends StatelessWidget {
  const CategoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return BlocProvider<CourseFiltersCubit>(
      create: (_) => sl<CourseFiltersCubit>()..loadCategories(),
      child: const CategoryListView(),
    );
  }
}

class CategoryListView extends StatelessWidget {
  const CategoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CustomAppBar(
        title: 'All Categories',
        centerTitle: true,
        titleColor: AppColors.textPrimary,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Target Bar
            // Padding(
            //   padding: Screen.getPadding(horizontal: 20, top: 12, bottom: 8),
            //   child: _SearchBar(
            //     onTap: () => context.push(AppRoutes.courseSearch),
            //   ),
            // ),

            // Categories Grid Section
            Expanded(
              child: BlocBuilder<CourseFiltersCubit, CourseFiltersState>(
                builder: (context, state) {
                  return state.maybeWhen(
                    loading: () => const _CategoryGridShimmer(),
                    loaded: (filterData) =>
                        _buildGrid(context, filterData.categories),
                    error: (msg) => _ErrorView(
                      message: msg,
                      onRetry: () =>
                          context.read<CourseFiltersCubit>().loadCategories(),
                    ),
                    orElse: () => const _CategoryGridShimmer(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<CourseCategory> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              "No categories available",
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final rh = ResponsiveHelper.of(context);
    final crossAxisCount = rh.isTablet ? 4 : (rh.isFold ? 3 : 2);

    return GridView.builder(
      padding: Screen.getPadding(horizontal: 20, vertical: 12),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: Screen.getVerticalSize(12),
        crossAxisSpacing: Screen.getHorizontalSize(12),
        mainAxisExtent: Screen.getVerticalSize(90),
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryListCard(
          category: category,
          onTap: () => context.push(
            '${AppRoutes.catalog}?categoryId=${category.categoryId}&title=${Uri.encodeComponent(category.categoryName)}',
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Premium Neumorphic Category Card (Matching HomePage design)
// ─────────────────────────────────────────────────────────────
class _CategoryListCard extends StatelessWidget {
  final CourseCategory category;
  final VoidCallback onTap;

  const _CategoryListCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusM);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.primary.withValues(alpha: 0.47);
    final innerColor = AppColors.primary.withValues(alpha: 0.12);

    return Container(
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
          // Card surface — solid white + gradient border.
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
                onTap: onTap,
                borderRadius: radius,
                splashColor: AppColors.primary.withValues(alpha: 0.10),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: Center(
                  child: Padding(
                    padding: Screen.getPadding(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: Screen.getVerticalSize(42),
                          width: Screen.getHorizontalSize(42),
                          child: Image.asset(
                            AppImages.bookImg, // Default book placeholder
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: Screen.getHorizontalSize(10)),
                        Expanded(
                          child: Text(
                            category.categoryName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: AppColors.primary,
                              fontSize: Screen.getFontSize(13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Inner shadow overlay
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

// ─────────────────────────────────────────────────────────────
// Error view
// ─────────────────────────────────────────────────────────────
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
// Category Grid Shimmer Loader
// ─────────────────────────────────────────────────────────────
class _CategoryGridShimmer extends StatelessWidget {
  const _CategoryGridShimmer();

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final crossAxisCount = rh.isTablet ? 4 : (rh.isFold ? 3 : 2);

    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 20, vertical: 12),
        itemCount: 8,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: Screen.getVerticalSize(12),
          crossAxisSpacing: Screen.getHorizontalSize(12),
          mainAxisExtent: Screen.getVerticalSize(90),
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
      ),
    );
  }
}
