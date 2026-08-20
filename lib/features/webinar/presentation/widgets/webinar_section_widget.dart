import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_card.dart';

/// The "Webinars" rail on Home — live and upcoming public classes: no
/// course and no enrolment needed, though some now carry a price of
/// their own, which the card shows.
///
/// Renders nothing at all when there are none, or while the first fetch
/// is still in flight: an empty-state card for a feature an educator may
/// simply not use would be a permanent blank box on every learner's home
/// screen. A failed fetch is silent for the same reason — the rail is
/// supplementary, and the dashboard around it is unaffected.
class WebinarSectionWidget extends StatelessWidget {
  const WebinarSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WebinarsCubit, WebinarsState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (webinars, liveCount, total, hasMore, _, __) {
            if (webinars.isEmpty) return const SizedBox.shrink();
            return _WebinarRail(
              webinars: webinars,
              liveCount: liveCount,
              // "View All" only earns its place when there is more than
              // the rail already holds.
              showViewAll: hasMore || total > webinars.length,
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _WebinarRail extends StatelessWidget {
  final List<WebinarItem> webinars;
  final int liveCount;
  final bool showViewAll;

  const _WebinarRail({
    required this.webinars,
    required this.liveCount,
    required this.showViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The rail carries its own top gap rather than taking one from
        // Home's column: when there are no webinars this widget collapses
        // to nothing, and a gap left behind on the page would be a
        // mystery hole above New Courses.
        SizedBox(height: Screen.getVerticalSize(25)),
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Webinars',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h5SemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: Screen.getFontSizeCapped(20),
                        ),
                      ),
                    ),
                    // Straight from `liveCount`, so the header can say
                    // how many are on air without scanning the list.
                    if (liveCount > 0) ...[
                      SizedBox(width: Screen.getHorizontalSize(8)),
                      _LiveCountPill(count: liveCount),
                    ],
                  ],
                ),
              ),
              if (showViewAll)
                InkWell(
                  onTap: () => context.push(AppRoutes.webinars),
                  child: Text(
                    'View All',
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

        // A horizontal ListView needs a bounded cross axis, so the rail
        // has to know how tall a card is before building one. The card
        // owns that arithmetic — measured against its own paddings and
        // the device's text scaler — rather than the rail guessing at it
        // and drifting into an overflow stripe the next time the card's
        // layout changes.
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = rh.courseCardWidth;
            final double cardHeight = WebinarCard.heightFor(context, cardWidth);

            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: rh.horizontalPadding),
                // Server order is authoritative — live first, then
                // soonest upcoming. Never re-sort here.
                itemCount: webinars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 15),
                itemBuilder: (context, index) => WebinarCard(
                  key: ValueKey(webinars[index].slug),
                  webinar: webinars[index],
                  cardWidth: cardWidth,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LiveCountPill extends StatelessWidget {
  final int count;

  const _LiveCountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        count == 1 ? '1 live now' : '$count live now',
        style: AppTypography.bodyTextSmallSemiBold.copyWith(
          color: AppColors.error,
          fontSize: Screen.getFontSizeCapped(11),
        ),
      ),
    );
  }
}
