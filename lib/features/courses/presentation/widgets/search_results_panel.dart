import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/rating_and_review_row_widget.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/search_courses_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Vertical search-results list driven by [SearchCoursesCubit].
///
/// The cubit must already be provided in the surrounding scope. The home
/// page wraps everything below the search bar in this panel only when the
/// query is non-empty; once it's empty, the panel is unmounted entirely.
class SearchResultsPanel extends StatelessWidget {
  final ScrollController scrollController;

  const SearchResultsPanel({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCoursesCubit, SearchCoursesState>(
      builder: (context, state) {
        return state.maybeWhen(
          loading: (query) => Center(
            child: Padding(
              padding: Screen.getPadding(vertical: 60),
              child: const CircularProgressIndicator(),
            ),
          ),
          loaded: (query, courses, hasMoreData, currentPage, isLoadingMore) {
            if (courses.isEmpty) return _Empty(query: query);
            return _ResultList(
              courses: courses,
              scrollController: scrollController,
              isLoadingMore: isLoadingMore,
            );
          },
          error: (message) => _Error(message: message),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String query;

  const _Empty({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: Screen.getSize(64),
            color: AppColors.grey300,
          ),
          SizedBox(height: Screen.getVerticalSize(12)),
          Text(
            'No courses match "$query"',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: Screen.getSize(64), color: AppColors.error),
          SizedBox(height: Screen.getVerticalSize(12)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  final List<CourseSummary> courses;
  final ScrollController scrollController;
  final bool isLoadingMore;

  const _ResultList({
    required this.courses,
    required this.scrollController,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    final count = courses.length + (isLoadingMore ? 1 : 0);
    return ListView.separated(
      controller: scrollController,
      padding: Screen.getPadding(horizontal: 20, vertical: 16),
      itemCount: count,
      separatorBuilder: (_, __) =>
          SizedBox(height: Screen.getVerticalSize(12)),
      itemBuilder: (_, index) {
        if (index == courses.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _SearchResultCard(course: courses[index]);
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final CourseSummary course;

  const _SearchResultCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      onTap: () => context.push(
        '${AppRoutes.courseDetail}?courseId=${course.courseId}',
      ),
      child: Container(
        width: double.infinity,
        padding: Screen.getPadding(all: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            CustomNetworkImage(
              url: course.courseImageUrl,
              width: Screen.getHorizontalSize(80),
              height: Screen.getVerticalSize(80),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              errorWidget: Container(
                width: Screen.getHorizontalSize(80),
                height: Screen.getVerticalSize(80),
                color: AppColors.grey100,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(12)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    reviewCount:
                        Utils.formatReviewCount(course.totalReviewsCounts),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
