import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/presentation/bloc/home_live_cubit.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_cover.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_live_badge.dart';

/// One course live class in the Home rail — the webinar card's poster
/// layout with the content swapped: course cover, LIVE badge or
/// countdown, title, "course · educator", and a footer whose label says
/// what the tap does.
///
/// The tap **never opens the player**. Purchased → the course on its
/// Content tab with the node highlighted (walking into its folder when
/// nested); not purchased → the course page, where the bottom bar
/// offers Buy Now. Joining stays where it already is: the live-class
/// row inside the course.
class HomeLiveCard extends StatelessWidget {
  final HomeLiveSessionItem session;
  final double cardWidth;

  const HomeLiveCard({
    super.key,
    required this.session,
    required this.cardWidth,
  });

  static const double _radius = AppSizes.radiusXL;

  /// Same arithmetic as the webinar card, shared with the rail so the
  /// two can never drift into an overflow stripe.
  static double heightFor(BuildContext context, double cardWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleLine = scaler.scale(Screen.getFontSize(14)) * 1.25;
    final subLine = scaler.scale(Screen.getFontSize(12)) * 1.3;
    return cardWidth * 9 / 16 +
        Screen.getVerticalSize(12) +
        titleLine * 2 +
        Screen.getVerticalSize(8) +
        subLine +
        Screen.getVerticalSize(10) +
        1 +
        Screen.getVerticalSize(10) +
        Screen.getSize(30) +
        Screen.getVerticalSize(12);
  }

  void _open(BuildContext context) {
    final title = Uri.encodeComponent(session.courseName ?? session.title);
    if (!session.opensContent) {
      // Not purchased (or an action this build doesn't know — the safe
      // direction): the course page, About tab, Buy Now in the bar.
      context.push(
        '${AppRoutes.courseDetail}?courseId=${session.courseId}&title=$title',
      );
      return;
    }
    final parents = session.parentNodeIds.map(Uri.encodeComponent).join(',');
    context.push(
      '${AppRoutes.courseDetail}'
      '?courseId=${session.courseId}'
      '&title=$title'
      '&tab=content'
      '&nodeId=${Uri.encodeComponent(session.nodeId)}'
      '&roomId=${Uri.encodeComponent(session.roomId)}'
      '${parents.isEmpty ? '' : '&parents=$parents'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLive = session.isOnAir;
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: AppDecorations.cardBorder(
          lightColor: isLive
              ? AppColors.error.withValues(alpha: 0.30)
              : AppColors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          ...AppDecorations.cardShadow(),
          if (isLive)
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.16),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(session: session),
              Expanded(child: _Body(session: session)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final HomeLiveSessionItem session;

  const _Cover({required this.session});

  @override
  Widget build(BuildContext context) {
    final duration = session.durationMin > 0
        ? WebinarFormatting.countdown(Duration(minutes: session.durationMin))
        : '';
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebinarCoverImage(
            url: session.courseImageUrl,
            fallback: const _CoverFallback(),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.black.withValues(alpha: 0.34),
                    AppColors.black.withValues(alpha: 0.04),
                    AppColors.black.withValues(alpha: 0.10),
                    AppColors.black.withValues(alpha: 0.66),
                  ],
                  stops: const [0.0, 0.28, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: Screen.getVerticalSize(9),
            left: Screen.getHorizontalSize(9),
            right: Screen.getHorizontalSize(9),
            child: Row(
              children: [
                // By phase: live wins over the clock (an educator may
                // start early); waiting = start time passed, not on air.
                if (session.isOnAir)
                  const WebinarLiveBadge()
                else if (session.isPaused)
                  const _PausedChip()
                else if (session.isWaitingForHost)
                  const _WaitingChip()
                else
                  _StartChip(session: session),
              ],
            ),
          ),
          Positioned(
            left: Screen.getHorizontalSize(9),
            right: Screen.getHorizontalSize(9),
            bottom: Screen.getVerticalSize(9),
            child: Row(
              children: [
                if (duration.isNotEmpty)
                  _GlassChip(icon: Icons.timelapse_rounded, label: duration),
                const Spacer(),
                if (!session.isPurchased)
                  const _GlassChip(icon: Icons.lock_rounded, label: 'Course'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(
        Icons.sensors_rounded,
        size: Screen.getSize(34),
        color: AppColors.primary,
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Screen.getSize(12), color: AppColors.alwaysWhite),
          SizedBox(width: Screen.getHorizontalSize(4)),
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(10),
            ),
          ),
        ],
      ),
    );
  }
}

/// The educator stopped mid-class — grey, neither LIVE nor a schedule.
/// Still joinable: the player waits and resumes when they are back.
class _PausedChip extends StatelessWidget {
  const _PausedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            size: Screen.getSize(12),
            color: AppColors.alwaysWhite,
          ),
          SizedBox(width: Screen.getHorizontalSize(4)),
          Text(
            'Paused',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Start time reached, educator not on air yet — amber, so it reads as
/// "any moment" rather than either LIVE or a schedule.
class _WaitingChip extends StatelessWidget {
  const _WaitingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: Screen.getSize(12),
            color: AppColors.alwaysWhite,
          ),
          SizedBox(width: Screen.getHorizontalSize(4)),
          Text(
            'Starting soon…',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-left when upcoming: a countdown inside 24h, else the local
/// date/time.
class _StartChip extends StatelessWidget {
  final HomeLiveSessionItem session;

  const _StartChip({required this.session});

  @override
  Widget build(BuildContext context) {
    return _Countdown(
      session: session,
      builder: (context, remaining) => _GlassChip(
        icon: Icons.schedule_rounded,
        label: _startLabel(session, remaining),
      ),
    );
  }
}

String _startLabel(HomeLiveSessionItem session, Duration remaining) {
  if (session.isOnAir) return 'Live now';
  if (session.isPaused) return 'Paused by the host';
  if (session.isWaitingForHost || remaining == Duration.zero) {
    return 'Starting soon…';
  }
  if (remaining.inHours < 24) {
    return 'Starts in ${WebinarFormatting.countdown(remaining)}';
  }
  return DateFormat('EEE, d MMM · h:mm a').format(session.scheduledAt);
}

/// Ticks [builder] from the session's server-anchored countdown: every
/// second inside the final hour, every minute before that, never at all
/// once live.
class _Countdown extends StatefulWidget {
  final HomeLiveSessionItem session;
  final Widget Function(BuildContext context, Duration remaining) builder;

  const _Countdown({required this.session, required this.builder});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _schedule();
  }

  bool _elapsedReported = false;

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final remaining = widget.session.timeUntilStart;
    if (widget.session.isOnAir || remaining == Duration.zero) return;
    final interval = remaining.inHours < 1
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {});
      final left = widget.session.timeUntilStart;
      if (left == Duration.zero && !_elapsedReported) {
        // The clock says it should be starting — ask the server whether
        // the educator is on air rather than waiting for the next poll.
        _elapsedReported = true;
        context.read<HomeLiveCubit>().onCountdownElapsed();
      }
      if (left == Duration.zero ||
          (left.inHours < 1 && interval != const Duration(seconds: 1))) {
        _schedule();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.session.timeUntilStart);
}

class _Body extends StatelessWidget {
  final HomeLiveSessionItem session;

  const _Body({required this.session});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      session.courseName,
      session.educatorName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
                height: 1.25,
                letterSpacing: -0.1,
              ),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(8)),
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: Screen.getSize(13),
                color: AppColors.primary,
              ),
              SizedBox(width: Screen.getHorizontalSize(6)),
              Expanded(
                child: Text(
                  subtitle.isEmpty ? 'Course live class' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontSize: Screen.getFontSize(12),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          const Spacer(),
          Divider(height: 1, thickness: 1, color: AppColors.grey200),
          SizedBox(height: Screen.getVerticalSize(10)),
          _Footer(session: session),
        ],
      ),
    );
  }
}

/// Countdown label on the left; on the right, a pill only when it says
/// something the card doesn't already — "Join in course" while live, or
/// "Buy course" behind the paywall. An upcoming class the learner already
/// owns gets no pill: the whole card is the tap, and "View in course"
/// was just restating that.
class _Footer extends StatelessWidget {
  final HomeLiveSessionItem session;

  const _Footer({required this.session});

  @override
  Widget build(BuildContext context) {
    final isLive = session.isOnAir;
    final waiting = session.isWaitingForHost;
    final paused = session.isPaused;
    final buy = !session.opensContent;
    final tone = isLive
        ? AppColors.error
        : paused
        ? AppColors.mutedTextPrimary
        : (waiting ? AppColors.warningDark : AppColors.primary);
    final size = Screen.getSize(30);

    return SizedBox(
      height: size,
      child: Row(
        children: [
          Expanded(
            child: _Countdown(
              session: session,
              builder: (context, remaining) => Container(
                padding: Screen.getPadding(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLive
                          ? Icons.sensors_rounded
                          : paused
                          ? Icons.pause_circle_outline_rounded
                          : (waiting
                                ? Icons.hourglass_top_rounded
                                : Icons.schedule_rounded),
                      size: Screen.getSize(13),
                      color: tone,
                    ),
                    SizedBox(width: Screen.getHorizontalSize(5)),
                    Flexible(
                      child: Text(
                        _startLabel(session, remaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextSmallSemiBold.copyWith(
                          color: tone,
                          fontSize: Screen.getFontSizeCapped(11.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isLive || buy) ...[
            SizedBox(width: Screen.getHorizontalSize(8)),
            Container(
              height: size,
              padding: Screen.getPadding(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 2),
                gradient: buy
                    ? AppColors.primaryGradient
                    : (isLive
                          ? AppColors.errorGradient
                          : AppColors.primaryGradient),
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (buy) ...[
                    Icon(
                      Icons.lock_rounded,
                      size: Screen.getSize(12),
                      color: AppColors.alwaysWhite,
                    ),
                    SizedBox(width: Screen.getHorizontalSize(4)),
                  ],
                  Text(
                    session.ctaLabel,
                    style: AppTypography.bodyTextXtraSmallBold.copyWith(
                      color: AppColors.alwaysWhite,
                      fontSize: Screen.getFontSizeCapped(10.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
