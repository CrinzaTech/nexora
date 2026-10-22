import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/payment_policy.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/usecases/bundle_usecases.dart';
import 'package:nexora/features/bundles/presentation/bloc/related_items_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/course_cover.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_product_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// X1 on the course page: "You may also need" — Store products the
/// educator linked to this course. Cross-sell only: a tap opens the
/// existing product page and buying goes through the Store's own cart.
///
/// Hidden while loading and when empty (no products linked, or the org
/// has no Store). Physical goods, so it stays on iOS.
class CourseRelatedProductsRail extends StatelessWidget {
  final int courseId;

  const CourseRelatedProductsRail({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RelatedItemsCubit<StoreProductCard>(
        () => sl<GetCourseRelatedProductsUseCase>()(courseId),
      )..load(),
      child:
          BlocBuilder<
            RelatedItemsCubit<StoreProductCard>,
            List<StoreProductCard>?
          >(
            builder: (context, products) {
              if (products == null || products.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StoreSectionHeader(title: 'You may also need'),
                  StoreProductRail(products: products),
                ],
              );
            },
          ),
    );
  }
}

/// X2 on a Store product page: "Courses for this product".
///
/// Hidden while loading and when empty. On iOS the cards keep the title
/// but drop the price (see [PaymentPolicy]).
class ProductRelatedCoursesRail extends StatelessWidget {
  final String productId;

  const ProductRelatedCoursesRail({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RelatedItemsCubit<RelatedCourse>(
        () => sl<GetProductRelatedCoursesUseCase>()(productId),
      )..load(),
      child:
          BlocBuilder<RelatedItemsCubit<RelatedCourse>, List<RelatedCourse>?>(
            builder: (context, courses) {
              if (courses == null || courses.isEmpty) {
                return const SizedBox.shrink();
              }
              final width = (MediaQuery.sizeOf(context).width * 0.58).clamp(
                200.0,
                280.0,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StoreSectionHeader(title: 'Courses for this product'),
                  SizedBox(
                    height: _RelatedCourseTile.heightFor(context, width) + 20,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // Room below for the card shadow.
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          _RelatedCourseTile(course: courses[i], width: width),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _RelatedCourseTile extends StatelessWidget {
  final RelatedCourse course;
  final double width;

  const _RelatedCourseTile({required this.course, required this.width});

  static const double _pad = 8;

  static double heightFor(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final image = (width - _pad * 2) * 9 / 16;
    final title = scaler.scale(Screen.getFontSize(14)) * 1.25 * 2;
    final price = scaler.scale(AppTypography.bodyTextSemiBold.fontSize ?? 14);
    return 10 + image + 10 + title + 6 + price * 1.4 + 10 + 8;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusL);
    return InkWell(
      onTap: () => context.push(
        '${AppRoutes.courseDetail}?courseId=${course.courseId}'
        '&title=${Uri.encodeComponent(course.title)}',
      ),
      borderRadius: radius,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: radius,
          border: AppDecorations.cardBorder(
            width: 1.5,
            lightColor: AppColors.primary.withValues(alpha: 0.25),
          ),
          boxShadow: AppDecorations.cardShadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CourseCoverImage(
                url: course.imageUrl,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            _price(),
          ],
        ),
      ),
    );
  }

  Widget _price() {
    final style = AppTypography.bodyTextSemiBold;
    if (course.isFree) {
      return Text('Free', style: style.copyWith(color: AppColors.success));
    }
    if (!PaymentPolicy.allowsPurchases) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'from ',
            style: style.copyWith(
              color: AppColors.mutedTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: StoreFormat.money(course.price)),
          if (course.originalPrice > course.price)
            TextSpan(
              text: '  ${StoreFormat.money(course.originalPrice)}',
              style: style.copyWith(
                color: AppColors.mutedTextPrimary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.mutedTextPrimary,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: AppColors.textPrimary),
    );
  }
}
