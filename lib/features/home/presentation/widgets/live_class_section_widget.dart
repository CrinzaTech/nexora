import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/courses/presentation/bloc/live_now_cubit.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_live_badge.dart';

/// The "Live now" rail on Home — a class the learner has already paid for
/// that is on air *this second*, and the one thing on this screen they
/// lose by not seeing.
///
/// All of the work is in [LiveNowCubit], including why it has to gather
/// the schedule itself and what it therefore cannot know. This just
/// draws whatever that says is live, and collapses to nothing when
/// nothing is — the same way the webinar rail does for an org that runs
/// no webinars, so an ordinary Home screen is unchanged.
class LiveClassSectionWidget extends StatelessWidget {
  const LiveClassSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveNowCubit, LiveNowState>(
      builder: (context, state) {
        final live = state.maybeWhen(
          loaded: (leads) => leads,
          orElse: () => const <LiveClassLead>[],
        );
        if (live.isEmpty) return const SizedBox.shrink();
        return _LiveRail(leads: live);
      },
    );
  }
}

class _LiveRail extends StatelessWidget {
  final List<LiveClassLead> leads;

  const _LiveRail({required this.leads});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The rail carries its own top gap rather than taking one from
        // Home's column: with nothing live it collapses to nothing, and a
        // gap left behind would be a mystery hole above the webinars.
        SizedBox(height: Screen.getVerticalSize(25)),
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Live now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSizeCapped(20),
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              const WebinarLiveBadge(),
            ],
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(12)),
        // A column, not a horizontal rail: being live is rare and
        // urgent, so each one gets a full-width row rather than asking
        // the learner to scroll sideways to find out what is on.
        ...leads.map(
          (lead) => Padding(
            padding: EdgeInsets.only(
              left: Screen.getHorizontalSize(20),
              right: Screen.getHorizontalSize(20),
              bottom: Screen.getVerticalSize(10),
            ),
            child: _LiveCourseCard(lead: lead),
          ),
        ),
      ],
    );
  }
}

class _LiveCourseCard extends StatelessWidget {
  final LiveClassLead lead;

  const _LiveCourseCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(lead.joinRoute),
        child: Padding(
          padding: EdgeInsets.all(Screen.getSize(10)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: SizedBox(
                  width: Screen.getSize(64),
                  height: Screen.getSize(64),
                  child: CustomNetworkImage(
                    url: lead.courseImageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lead.node.nodeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(2)),
                    Text(
                      lead.courseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(10)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Screen.getHorizontalSize(14),
                  vertical: Screen.getVerticalSize(8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  'Join',
                  style: AppTypography.bodyTextXtraSmallBold.copyWith(
                    color: AppColors.alwaysWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
