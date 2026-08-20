import 'dart:async';

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
import 'package:nexora/core/widgets/scrolling_title.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/course_filters_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_list_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/course_filter_sheet.dart';
import 'package:nexora/features/courses/presentation/widgets/view_demo_buy_now_row_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

/// Dynamic Catalog Screen
/// Displays horizontal category chips loaded dynamically,
/// and dynamically fetches the list of courses under the selected category.
class CatalogPage extends StatelessWidget {
  final String title;
  final String? searchQuery;
  final int? categoryId;
  final int? tileId;
  final int? courseStatusType;
  final String? courseType;
  final CatalogSortBy? sortBy;

  const CatalogPage({
    super.key,
    required this.title,
    this.searchQuery,
    this.categoryId,
    this.tileId,
    this.courseStatusType,
    this.courseType,
    this.sortBy,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider<CourseFiltersCubit>(
          create: (_) => sl<CourseFiltersCubit>()..loadCategories(),
        ),
        BlocProvider<CourseListCubit>(create: (_) => sl<CourseListCubit>()),
      ],
      child: CatalogView(
        title: title,
        searchQuery: searchQuery,
        categoryId: categoryId,
        tileId: tileId,
        courseStatusType: courseStatusType,
        courseType: courseType,
        sortBy: sortBy,
      ),
    );
  }
}

class CatalogView extends StatefulWidget {
  final String title;
  final String? searchQuery;
  final int? categoryId;
  final int? tileId;
  final int? courseStatusType;
  final String? courseType;
  final CatalogSortBy? sortBy;

  const CatalogView({
    super.key,
    required this.title,
    this.searchQuery,
    this.categoryId,
    this.tileId,
    this.courseStatusType,
    this.courseType,
    this.sortBy,
  });

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  int? _selectedCategoryId;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  // Persists the last-applied filter selection so the sheet reopens
  // with chips in the correct state.
  CourseFilters _activeFilters = const CourseFilters();

  bool? get _isPaid {
    if (widget.courseType == null) return null;
    final type = widget.courseType!.toLowerCase().trim();
    if (type == 'paid') return true;
    if (type == 'free') return false;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;

    // Load initial courses based on parameters if categoryId, tileId, courseStatusType, sortBy, or searchQuery is provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tileId != null) {
        context.read<CourseListCubit>().loadByTile(
          widget.tileId!,
          isPaid: _isPaid,
        );
      } else if (widget.categoryId != null) {
        context.read<CourseListCubit>().loadByCategory(
          widget.categoryId!,
          isPaid: _isPaid,
        );
      } else if (widget.courseStatusType != null) {
        context.read<CourseListCubit>().loadByStatusType(
          widget.courseStatusType!,
          isPaid: _isPaid,
        );
      } else if (widget.sortBy != null) {
        context.read<CourseListCubit>().loadBySortBy(
          widget.sortBy!,
          isPaid: _isPaid,
        );
      } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        context.read<CourseListCubit>().loadBySearchQuery(
          widget.searchQuery!,
          isPaid: _isPaid,
        );
      } else {
        context.read<CourseListCubit>().loadCatalog(
          isPaid: _isPaid,
        );
      }
    });
  }

  /// Called on every keystroke inside the inline search field.
  /// Fires a debounced catalog search (≥3 chars), or resets to the
  /// page's original load parameters when the query is cleared.
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < 3) {
      // If user cleared the search, reload from the page's original params.
      if (trimmed.isEmpty) {
        _reloadOriginal();
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<CourseListCubit>().loadBySearchQuery(
        trimmed,
        isPaid: _isPaid,
      );
    });
  }

  /// Clears the inline search and re-applies the page's original load.
  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    _reloadOriginal();
  }

  /// Reloads the list using the widget's original routing parameters,
  /// ignoring any inline search the user may have typed.
  void _reloadOriginal() {
    if (!mounted) return;
    final cubit = context.read<CourseListCubit>();
    if (widget.tileId != null) {
      cubit.loadByTile(widget.tileId!, isPaid: _isPaid);
    } else if (widget.categoryId != null) {
      cubit.loadByCategory(widget.categoryId!, isPaid: _isPaid);
    } else if (widget.courseStatusType != null) {
      cubit.loadByStatusType(widget.courseStatusType!, isPaid: _isPaid);
    } else if (widget.sortBy != null) {
      cubit.loadBySortBy(widget.sortBy!, isPaid: _isPaid);
    } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      cubit.loadBySearchQuery(widget.searchQuery!, isPaid: _isPaid);
    } else {
      cubit.loadCatalog(isPaid: _isPaid);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: AppColors.white,
                surfaceTintColor: AppColors.white,
                elevation: 0,
                pinned: true,
                floating: true,
                centerTitle: true,
                leading: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                      size: Screen.getSize(28),
                    ),
                  ),
                ),
                title: ScrollingTitle(
                  text: widget.title,
                  style: AppTypography.h6SemiBold.copyWith(color: AppColors.textPrimary),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(Screen.getVerticalSize(66)),
                  child: Container(
                    color: AppColors.alwaysWhite,
                    padding: Screen.getPadding(horizontal: 20, top: 12, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            hintText: widget.searchQuery != null &&
                                    widget.searchQuery!.isNotEmpty
                                ? 'Search: "${widget.searchQuery}"'
                                : 'Search available courses...',
                            onChanged: _onSearchChanged,
                            onClear: _clearSearch,
                          ),
                        ),
                        SizedBox(width: Screen.getHorizontalSize(10)),
                        _FilterButton(
                          onTap: () async {
                            final filters = await CourseFilterSheet.show(
                              context,
                              initial: _activeFilters,
                            );
                            if (filters == null || !context.mounted) return;

                            // Persist the selection for the next sheet open.
                            setState(() => _activeFilters = filters);

                            // Derive isPaid from the selected course-type chip.
                            final bool? isPaidFilter = filters.typeId == null
                                ? null
                                : filters.typeName.toLowerCase() == 'paid'
                                ? true
                                : filters.typeName.toLowerCase() == 'free'
                                ? false
                                : null;

                            final cubit = context.read<CourseListCubit>();

                            // Category filter overrides everything else.
                            if (filters.categoryId != null) {
                              cubit.loadByCategory(
                                filters.categoryId!,
                                isPaid: isPaidFilter,
                              );
                            } else if (widget.tileId != null) {
                              cubit.loadByTile(
                                widget.tileId!,
                                isPaid: isPaidFilter ?? _isPaid,
                              );
                            } else if (widget.courseStatusType != null) {
                              cubit.loadByStatusType(
                                widget.courseStatusType!,
                                isPaid: isPaidFilter ?? _isPaid,
                              );
                            } else if (widget.sortBy != null) {
                              cubit.loadBySortBy(
                                widget.sortBy!,
                                isPaid: isPaidFilter ?? _isPaid,
                              );
                            } else if (widget.searchQuery != null &&
                                widget.searchQuery!.isNotEmpty) {
                              cubit.loadBySearchQuery(
                                widget.searchQuery!,
                                isPaid: isPaidFilter ?? _isPaid,
                              );
                            } else {
                              cubit.loadCatalog(isPaid: isPaidFilter ?? _isPaid);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                context.read<CourseListCubit>().loadNextPage();
              }
              return false;
            },
            child: BlocBuilder<CourseListCubit, CourseListState>(
              builder: (context, state) {
                return state.maybeWhen(
                  loading: () => const _CourseListShimmer(),
                  loaded:
                      (courses, hasMoreData, currentPage, isLoadingMore) =>
                          _buildCourseList(context, courses, isLoadingMore),
                  error: (msg) => _ErrorView(
                    message: msg,
                    onRetry: () {
                      if (widget.tileId != null) {
                        context.read<CourseListCubit>().loadByTile(
                          widget.tileId!,
                          isPaid: _isPaid,
                        );
                      } else if (_selectedCategoryId != null) {
                        context.read<CourseListCubit>().loadByCategory(
                          _selectedCategoryId!,
                          isPaid: _isPaid,
                        );
                      } else if (widget.courseStatusType != null) {
                        context.read<CourseListCubit>().loadByStatusType(
                          widget.courseStatusType!,
                          isPaid: _isPaid,
                        );
                      } else if (widget.sortBy != null) {
                        context.read<CourseListCubit>().loadBySortBy(
                          widget.sortBy!,
                          isPaid: _isPaid,
                        );
                      } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
                        context.read<CourseListCubit>().loadBySearchQuery(
                          widget.searchQuery!,
                          isPaid: _isPaid,
                        );
                      } else {
                        context.read<CourseListCubit>().loadCatalog(
                          isPaid: _isPaid,
                        );
                      }
                    },
                  ),
                  orElse: () => const Center(
                    child: Text('Select a category to browse courses'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCategoryChips(
    BuildContext context,
    List<CourseCategory> categories,
  ) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: Screen.getVerticalSize(54),
      child: ListView.separated(
        padding: Screen.getPadding(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            SizedBox(width: Screen.getHorizontalSize(10)),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.categoryId == _selectedCategoryId;
          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                _selectedCategoryId = category.categoryId;
              });
              context.read<CourseListCubit>().loadByCategory(
                category.categoryId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category.categoryName,
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: isSelected ? AppColors.alwaysWhite : AppColors.primary,
                  fontSize: Screen.getFontSize(13),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseList(
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
              "No courses in this category yet",
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
      padding: Screen.getPadding(horizontal: 20, vertical: 12),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: Screen.getVerticalSize(12)),
      itemBuilder: (context, index) {
        if (index == courses.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final course = courses[index];
        return _CourseCard(
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
// Interactive search bar — inline text field with debounce
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Screen.getVerticalSize(46),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: Screen.getHorizontalSize(16)),
          Icon(
            Icons.search,
            color: AppColors.mutedTextPrimary,
            size: Screen.getSize(20),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.grey400,
                  fontSize: Screen.getFontSize(14),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
          // Clear button — only visible when there is text.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Screen.getHorizontalSize(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedTextPrimary,
                    size: Screen.getSize(18),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isNotEmpty) return const SizedBox.shrink();
              return SizedBox(width: Screen.getHorizontalSize(16));
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Beautiful Catalog Course Card
// ─────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CourseSummary course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: CustomNetworkImage(
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
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              course.courseTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(6)),
          RatingAndReviewRowWidget(
            rating: course.rating.toString(),
            reviewCount: Utils.formatReviewCount(course.totalReviewsCounts),
          ),
          SizedBox(height: Screen.getVerticalSize(12)),
          ViewDemoBuyNowRow(
            courseId: course.courseId,
            showViewDetails: true,
            showViewDemo: false,
            showBuyNow: course.isPurchased == false,
            onPurchased: () => context
                .read<CourseListCubit>()
                .updatePurchasedStatus(course.courseId, true),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error views
// ─────────────────────────────────────────────────────────────
// ignore: unused_element
class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyTextMedium.copyWith(color: AppColors.error),
        ),
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
// Shimmer Loaders
// ─────────────────────────────────────────────────────────────
// ignore: unused_element
class _CategoryChipsShimmer extends StatelessWidget {
  const _CategoryChipsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: SizedBox(
        height: Screen.getVerticalSize(54),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: Screen.getPadding(horizontal: 20, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) =>
              SizedBox(width: Screen.getHorizontalSize(10)),
          itemBuilder: (_, __) => Container(
            width: Screen.getHorizontalSize(80),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseListShimmer extends StatelessWidget {
  const _CourseListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 20, vertical: 12),
        itemCount: 3,
        separatorBuilder: (_, __) =>
            SizedBox(height: Screen.getVerticalSize(12)),
        itemBuilder: (_, __) => Container(
          padding: Screen.getPadding(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
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
              Container(
                height: Screen.getVerticalSize(160),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(6)),
              Container(
                width: Screen.getHorizontalSize(150),
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(14)),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                  SizedBox(width: Screen.getHorizontalSize(12)),
                  Expanded(
                    child: Container(
                      height: 40,
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
