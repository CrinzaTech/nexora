import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/payment_policy.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/course_access_events.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/view_all_button.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/usecases/bundle_usecases.dart';
import 'package:nexora/features/bundles/presentation/bloc/bundles_cubit.dart';
import 'package:nexora/features/bundles/presentation/bloc/related_items_cubit.dart';
import 'package:nexora/features/bundles/presentation/widgets/bundle_tile.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// The "Course Bundles" rail on Home (B1). Needs a [BundlesCubit] above.
///
/// Renders nothing while loading, on error, when empty, and on iOS —
/// a bundle is purely a purchase, which the iOS build doesn't offer
/// (see [PaymentPolicy]). Carries its own top gap so that collapsing
/// leaves no hole in Home's column.
class HomeBundlesSection extends StatelessWidget {
  const HomeBundlesSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PaymentPolicy.allowsPurchases) return const SizedBox.shrink();
    return BlocBuilder<BundlesCubit, BundlesState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (bundles, total, hasMore, _, _) {
          if (bundles.isEmpty) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: Screen.getVerticalSize(25)),
              Padding(
                padding: Screen.getPadding(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Course Bundles',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Same heading style as the other Home sections.
                        style: AppTypography.bodyTextLargeMedium.copyWith(
                          color: AppColors.primary,
                          fontSize: Screen.getFontSizeCapped(16),
                        ),
                      ),
                    ),
                    if (hasMore || total > bundles.length)
                      ViewAllButton(
                        onTap: () => context.push(AppRoutes.bundles),
                      ),
                  ],
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(15)),
              BundleRailList(bundles: bundles),
            ],
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

/// Horizontal list of [BundleTile]s with a bounded height.
class BundleRailList extends StatelessWidget {
  final List<BundleCard> bundles;
  final EdgeInsetsGeometry? padding;

  const BundleRailList({super.key, required this.bundles, this.padding});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final width = rh.courseCardWidth;
    return SizedBox(
      height: BundleTile.heightFor(context, width),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            padding ?? EdgeInsets.symmetric(horizontal: rh.horizontalPadding),
        // Server order is authoritative (B3: cheapest first).
        itemCount: bundles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 15),
        itemBuilder: (context, i) => BundleTile(
          key: ValueKey(bundles[i].bundleId),
          bundle: bundles[i],
          width: width,
        ),
      ),
    );
  }
}

/// B3 on the course page: "Save more: get this course in a bundle".
///
/// Hidden on iOS, while loading, and when the course is in no bundle.
/// [onCoursesUnlocked] fires when a bundle bought from here (or anywhere)
/// unlocks courses, so the course page can re-read its access.
class CourseBundlesRail extends StatelessWidget {
  final int courseId;
  final VoidCallback? onCoursesUnlocked;
  final EdgeInsetsGeometry listPadding;

  const CourseBundlesRail({
    super.key,
    required this.courseId,
    this.onCoursesUnlocked,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 15),
  });

  @override
  Widget build(BuildContext context) {
    if (!PaymentPolicy.allowsPurchases) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => RelatedItemsCubit<BundleCard>(
        () => sl<GetBundlesForCourseUseCase>()(courseId),
      )..load(),
      child: _UnlockListener(
        onUnlocked: onCoursesUnlocked,
        child: BlocBuilder<RelatedItemsCubit<BundleCard>, List<BundleCard>?>(
          builder: (context, bundles) {
            if (bundles == null || bundles.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoreSectionHeader(
                  title: 'Save more',
                  subtitle: 'Get this course in a bundle',
                  padding: listPadding.add(
                    const EdgeInsets.only(top: 24, bottom: 12),
                  ),
                ),
                BundleRailList(bundles: bundles, padding: listPadding),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Re-reads its rail and tells the host page when courses unlock.
class _UnlockListener extends StatefulWidget {
  final VoidCallback? onUnlocked;
  final Widget child;

  const _UnlockListener({required this.onUnlocked, required this.child});

  @override
  State<_UnlockListener> createState() => _UnlockListenerState();
}

class _UnlockListenerState extends State<_UnlockListener> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = CourseAccessEvents.unlocked.listen((_) {
      if (!mounted) return;
      // `isPurchased` / "Your price" on these cards just changed.
      context.read<RelatedItemsCubit<BundleCard>>().load();
      widget.onUnlocked?.call();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
