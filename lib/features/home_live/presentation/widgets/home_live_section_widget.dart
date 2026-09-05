import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/presentation/bloc/home_live_cubit.dart';
import 'package:nexora/features/home_live/presentation/widgets/home_live_card.dart';

/// The "Live classes" rail on Home — the course live classes in the
/// learner's organisation that are running right now or still to come,
/// filtered server-side by the educator's per-class audience toggle.
///
/// Mirrors the Webinars rail: renders nothing when the list is empty,
/// while the first fetch is in flight, or on error — an org that runs no
/// live classes must not get a permanent empty box. A tap never opens
/// the player; it sends the learner to the course (see [HomeLiveCard]).
class HomeLiveSectionWidget extends StatelessWidget {
  const HomeLiveSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeLiveCubit, HomeLiveState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (sessions, liveCount, _, __, ___, ____) {
            if (sessions.isEmpty) return const SizedBox.shrink();
            return _LiveRail(sessions: sessions, liveCount: liveCount);
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _LiveRail extends StatelessWidget {
  final List<HomeLiveSessionItem> sessions;
  final int liveCount;

  const _LiveRail({required this.sessions, required this.liveCount});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The rail carries its own top gap: with nothing to show it
        // collapses to nothing, and a gap left behind would be a mystery
        // hole above the webinars.
        SizedBox(height: Screen.getVerticalSize(25)),
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Live classes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSizeCapped(20),
                  ),
                ),
              ),
              if (liveCount > 0) ...[
                SizedBox(width: Screen.getHorizontalSize(8)),
                _LiveCountPill(count: liveCount),
              ],
            ],
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(15)),
        // The card owns its height arithmetic (measured against the text
        // scaler) so the row can never overflow under large type.
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = rh.courseCardWidth;
            final double cardHeight = HomeLiveCard.heightFor(context, cardWidth);
            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: rh.horizontalPadding),
                // Server order is authoritative — never re-sort.
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 15),
                itemBuilder: (context, index) => HomeLiveCard(
                  key: ValueKey(sessions[index].roomId),
                  session: sessions[index],
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
