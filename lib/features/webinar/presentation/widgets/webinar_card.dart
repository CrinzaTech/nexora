import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_countdown.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_cover.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_external_join.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_live_badge.dart';

/// One webinar in the Home rail.
///
/// Built as a **poster, not a form**: the cover runs edge to edge under
/// the badges, and the four facts a learner decides on — is it live, what
/// does it cost, how long is it, when does it start — sit on the art
/// itself rather than queued up as labelled rows underneath. That is what
/// separates a card someone wants to tap from a row of data.
///
/// The layout is deliberately fixed-height (see [heightFor]): the rail
/// hands every card the same box, and a title that wraps to one line
/// instead of two must not float its footer up out of line with the card
/// beside it. So the text block flexes and the meta footer is pinned.
class WebinarCard extends StatelessWidget {
  final WebinarItem webinar;
  final double cardWidth;

  const WebinarCard({
    super.key,
    required this.webinar,
    required this.cardWidth,
  });

  static const double _radius = AppSizes.radiusXL;

  /// Cover, then title, host, rule and footer — measured rather than
  /// guessed, and **shared with the rail** so the two can never drift
  /// into an overflow stripe.
  ///
  /// Text heights are scaled by the device's own text scaler: a learner
  /// running large type gets a taller card rather than a clipped one.
  static double heightFor(BuildContext context, double cardWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleLine = scaler.scale(Screen.getFontSize(14)) * 1.25;
    final hostLine = scaler.scale(Screen.getFontSize(12)) * 1.3;

    return cardWidth * 9 / 16 // cover
        +
        Screen.getVerticalSize(12) // content top
        +
        titleLine * 2 // title, two lines
        +
        Screen.getVerticalSize(8) +
        hostLine // host
        +
        Screen.getVerticalSize(10) +
        1 // hairline
        +
        Screen.getVerticalSize(10) +
        Screen.getSize(30) // footer
        +
        Screen.getVerticalSize(12); // content bottom
  }

  @override
  Widget build(BuildContext context) {
    final isLive = webinar.isLive;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: AppDecorations.cardBorder(
          // A live class gets a warm rim; everything else keeps the
          // near-invisible hairline, so "live" is the only thing on the
          // rail asking for attention.
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
      // Material + InkWell *inside* the decorated box: wrapped around it
      // the ripple paints behind an opaque card and is never seen, which
      // is why this card used to feel unresponsive to the touch.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            '${AppRoutes.webinarDetail}'
            '?slug=${Uri.encodeComponent(webinar.slug)}',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(webinar: webinar),
              Expanded(child: _Body(webinar: webinar)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The poster half: art, a scrim, and the facts that read best on top of
/// it.
class _Cover extends StatelessWidget {
  final WebinarItem webinar;

  const _Cover({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final duration = WebinarFormatting.duration(webinar);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The whole cover, never a crop: a portrait poster in a 16:9
          // box would otherwise show a band across its middle, which is
          // usually the part carrying neither the title nor the face.
          //
          // Presigned and short-lived: never cached to disk by URL —
          // CustomNetworkImage strips the signature for its cache key,
          // so a re-fetched link reuses the bytes it already holds.
          WebinarCoverImage(
            url: webinar.thumbnailUrl,
            fallback: _CoverFallback(webinar: webinar),
          ),

          // Two scrims, not one. The bottom band is what makes the price
          // and duration legible over a bright photo; the top is a much
          // lighter wash so the LIVE pill doesn't sit on a white sky.
          const _Scrim(),

          Positioned(
            top: Screen.getVerticalSize(9),
            left: Screen.getHorizontalSize(9),
            right: Screen.getHorizontalSize(9),
            child: Row(
              children: [
                if (webinar.isLive)
                  const WebinarLiveBadge()
                else if (webinar.isRegistered)
                  const _RegisteredPill(),
                const Spacer(),
                // Only where joining does something other than play a
                // stream — "Crinza Live" on every card would be noise,
                // while "Zoom" or "Workshop" changes what the learner is
                // signing up for.
                if (!webinar.isStream)
                  WebinarPlatformBadge(
                    platformName: webinar.platformName,
                    joinMode: webinar.joinMode,
                    compact: true,
                  ),
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
                _PricePill(webinar: webinar),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top wash + bottom band, so overlaid text stays readable on any cover
/// without dimming the middle of the image where the subject usually is.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
    );
  }
}

/// Title, host, and the pinned footer that carries the countdown.
class _Body extends StatelessWidget {
  final WebinarItem webinar;

  const _Body({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              webinar.title,
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

          // The host is the reason a learner joins a webinar as often as
          // the topic is, so it gets a face-shaped mark rather than a
          // fourth grey line of metadata.
          Row(
            children: [
              Container(
                width: Screen.getSize(18),
                height: Screen.getSize(18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: Screen.getSize(11),
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(6)),
              Expanded(
                child: Text(
                  webinar.educatorName ?? 'Crinza',
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
          // Any height the title didn't use collects here rather than
          // under the footer, so the rule and the countdown sit on the
          // same line across every card in the rail — a one-line title
          // next to a two-line one is the fastest way to make a row of
          // cards look hand-placed.
          const Spacer(),
          Divider(height: 1, thickness: 1, color: AppColors.grey200),
          SizedBox(height: Screen.getVerticalSize(10)),

          _Footer(webinar: webinar),
        ],
      ),
    );
  }
}

/// When it starts, and an affordance saying the whole card is tappable.
class _Footer extends StatelessWidget {
  final WebinarItem webinar;

  const _Footer({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final isLive = webinar.isLive;
    final tone = isLive ? AppColors.error : AppColors.primary;
    final size = Screen.getSize(30);

    return SizedBox(
      height: size,
      child: Row(
        children: [
          Expanded(
            child: WebinarCountdown(
              webinar: webinar,
              builder: (context, _) {
                // Recomputed from the ticking countdown so "Starts in
                // 12m 30s" stays honest between refreshes.
                final label = WebinarFormatting.startLabel(webinar);
                return Container(
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
                            : Icons.schedule_rounded,
                        size: Screen.getSize(13),
                        color: tone,
                      ),
                      SizedBox(width: Screen.getHorizontalSize(5)),
                      Flexible(
                        child: Text(
                          label,
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
                );
              },
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isLive
                  ? AppColors.errorGradient
                  : AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: tone.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isLive ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
              size: Screen.getSize(16),
              color: AppColors.alwaysWhite,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Live now" / "Starts in 4h 12m" / "Mon, 24 Aug · 8:00 PM", ticking
/// itself down. The detail header's version of what the card's footer
/// shows.
class WebinarStartLabel extends StatelessWidget {
  final WebinarItem webinar;
  final double? fontSize;

  /// Fired when the countdown hits zero — the detail screen uses it to
  /// re-read the gate, since that is the moment the class may go live.
  final VoidCallback? onElapsed;

  const WebinarStartLabel({
    super.key,
    required this.webinar,
    this.fontSize,
    this.onElapsed,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = webinar.isLive;

    return WebinarCountdown(
      webinar: webinar,
      onElapsed: onElapsed,
      builder: (context, _) {
        final label = WebinarFormatting.startLabel(webinar);
        return Row(
          children: [
            Icon(
              isLive ? Icons.sensors_rounded : Icons.schedule_rounded,
              size: Screen.getSize(14),
              color: isLive ? AppColors.error : AppColors.primary,
            ),
            SizedBox(width: Screen.getHorizontalSize(4)),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: isLive ? AppColors.error : AppColors.primary,
                  fontSize: fontSize ?? Screen.getFontSize(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The price, over the art.
///
/// Free reads as a green *invitation* and a price as a crisp white pill:
/// on a rail where most webinars are free, "Free" is the thing worth
/// making inviting, and a number is the thing worth making unambiguous.
///
/// Read from `isFree`, never `isPaid` — a paid webinar discounted to
/// zero is free, and a card reading "₹ 0" beside a Buy button is the bug
/// that distinction exists to prevent.
class _PricePill extends StatelessWidget {
  final WebinarItem webinar;

  const _PricePill({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final free = webinar.isFree;

    return Container(
      padding: Screen.getPadding(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: free ? AppColors.success : AppColors.alwaysWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        free ? 'FREE' : WebinarFormatting.price(webinar),
        style: AppTypography.bodyTextXtraSmallBold.copyWith(
          color: free
              ? AppColors.alwaysWhite
              : AppColors.black.withValues(alpha: 0.88),
          fontSize: Screen.getFontSizeCapped(free ? 9.5 : 11),
          letterSpacing: free ? 0.6 : 0,
        ),
      ),
    );
  }
}

/// A frosted chip for facts that sit on the artwork — dark enough to
/// hold white text over a bright photo, quiet enough not to compete with
/// the price beside it.
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(
          color: AppColors.alwaysWhite.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Screen.getSize(11),
            color: AppColors.alwaysWhite.withValues(alpha: 0.92),
          ),
          SizedBox(width: Screen.getHorizontalSize(4)),
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(9.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on an upcoming webinar the learner has already signed up for.
/// A label, not a gate — the API allows rejoining freely.
class _RegisteredPill extends StatelessWidget {
  const _RegisteredPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: Screen.getSize(11),
            color: AppColors.alwaysWhite,
          ),
          SizedBox(width: Screen.getHorizontalSize(3)),
          Text(
            'REGISTERED',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in when a webinar has no thumbnail, or its presigned URL has
/// expired between the fetch and the render.
///
/// A branded panel rather than a grey box: plenty of webinars ship
/// without a cover, and an empty slab is the single clearest way for a
/// rail to look unfinished.
class _CoverFallback extends StatelessWidget {
  final WebinarItem webinar;

  const _CoverFallback({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.secondary.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          switch (webinar.joinMode) {
            WebinarJoinMode.location => Icons.location_on_rounded,
            WebinarJoinMode.meeting => Icons.videocam_rounded,
            WebinarJoinMode.stream => webinar.isLive
                ? Icons.podcasts_rounded
                : Icons.video_camera_front_outlined,
          },
          color: AppColors.alwaysWhite.withValues(alpha: 0.85),
          size: Screen.getSize(34),
        ),
      ),
    );
  }
}
