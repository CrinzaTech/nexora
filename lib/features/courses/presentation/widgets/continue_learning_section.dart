import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// "Continue your purchase" section for the home page — vertical list of
/// the user's recently-viewed / in-progress courses with a Buy Now CTA.
///
/// When [cubit] is supplied the section uses it via [BlocProvider.value] so
/// the caller can observe the same state (e.g. to drive a dynamic spacer).
/// When omitted the section creates and owns its own cubit.
/// Hides itself entirely when the list is empty.
/// Shows at most [_kMaxVisible] cards to keep the home layout predictable.
class ContinueLearningSection extends StatelessWidget {
  final ContinueCoursesCubit? cubit;

  const ContinueLearningSection({super.key, this.cubit});

  static const int _kMaxVisible = 2;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _ContinueLearningView(),
      );
    }
    return BlocProvider(
      create: (_) => sl<ContinueCoursesCubit>()..load(),
      child: const _ContinueLearningView(),
    );
  }
}

class _ContinueLearningView extends StatelessWidget {
  const _ContinueLearningView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinueCoursesCubit, ContinueCoursesState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (courses) {
            if (courses.isEmpty) return const SizedBox.shrink();
            final visible = courses.take(ContinueLearningSection._kMaxVisible).toList();
            return _Section(courses: visible);
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final List<CourseSummary> courses;

  const _Section({required this.courses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue your purchase :',
            style: AppTypography.h5SemiBold.copyWith(color: AppColors.alwaysWhite),
          ),
          SizedBox(height: Screen.getVerticalSize(12)),
          ...List.generate(courses.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < courses.length - 1
                    ? Screen.getVerticalSize(10)
                    : 0,
              ),
              child: _ContinueCourseCard(course: courses[i]),
            );
          }),
        ],
      ),
    );
  }
}

class _ContinueCourseCard extends StatelessWidget {
  final CourseSummary course;

  const _ContinueCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '${AppRoutes.courseDetail}?courseId=${course.courseId}',
      ),
      child: Container(
        padding: Screen.getPadding(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: AppDecorations.cardBorder(),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Course thumbnail — square, fixed size
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: CustomNetworkImage(
                url: course.courseImageUrl,
                height: Screen.getVerticalSize(110),
                width: Screen.getHorizontalSize(110),
                fit: BoxFit.cover,
                errorWidget: Container(
                  height: Screen.getVerticalSize(110),
                  width: Screen.getHorizontalSize(110),
                  color: AppColors.grey100,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.grey300,
                  ),
                ),
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(14)),

            // Title + CTA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    course.courseTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h5SemiBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: Screen.getFontSize(15),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(12)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(
                        '${AppRoutes.courseDetail}?courseId=${course.courseId}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: Screen.getVerticalSize(13),
                        ),
                      ),
                      child: Text(
                        course.isCourseFree ? 'Get Free Access' : 'Buy Now',
                        style: AppTypography.bodyTextLargeSemiBold.copyWith(
                          color: AppColors.alwaysWhite,
                          fontSize: Screen.getFontSize(14),
                        ),
                      ),
                    ),
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
