import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_card.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_cover.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_external_join.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_live_badge.dart';

/// The full webinar list behind Home's "View All".
///
/// Uses its own [WebinarsCubit] rather than the Dashboard's, so paging
/// through 60 webinars here doesn't leave the Home rail holding all of
/// them.
class WebinarsPage extends StatelessWidget {
  const WebinarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<WebinarsCubit>()..load(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: const CustomAppBar(title: 'Webinars'),
        body: SafeArea(
          child: BlocBuilder<WebinarsCubit, WebinarsState>(
            builder: (context, state) {
              return state.maybeWhen(
                loaded: (webinars, liveCount, total, hasMore, pageNo, more) =>
                    _WebinarList(
                      webinars: webinars,
                      hasMore: hasMore,
                      isLoadingMore: more,
                    ),
                error: (message) => _Refreshable(
                  child: _Message(
                    icon: Icons.error_outline,
                    iconColor: AppColors.error,
                    title: 'Something went wrong',
                    body: message,
                  ),
                ),
                orElse: () => const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WebinarList extends StatefulWidget {
  final List<WebinarItem> webinars;
  final bool hasMore;
  final bool isLoadingMore;

  const _WebinarList({
    required this.webinars,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  State<_WebinarList> createState() => _WebinarListState();
}

class _WebinarListState extends State<_WebinarList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !widget.hasMore) return;
    final position = _scrollController.position;
    // Fetch a screen ahead of the bottom so the next page is usually
    // there by the time the learner reaches it. The cubit drops
    // re-entrant calls, so a fast fling firing this twice is harmless.
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<WebinarsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.webinars.isEmpty) {
      return const _Refreshable(
        child: _Message(
          icon: Icons.video_camera_front_outlined,
          title: 'No webinars right now',
          body:
              'Live and upcoming webinars from your institute will show up '
              'here.',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<WebinarsCubit>().silentRefresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 20, vertical: 16),
        // Server order is authoritative: live first, then soonest.
        itemCount: widget.webinars.length + (widget.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            SizedBox(height: Screen.getVerticalSize(14)),
        itemBuilder: (_, i) {
          if (i >= widget.webinars.length) {
            return Padding(
              padding: Screen.getPadding(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: Screen.getSize(22),
                  height: Screen.getSize(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          final webinar = widget.webinars[i];
          return _WebinarTile(key: ValueKey(webinar.slug), webinar: webinar);
        },
      ),
    );
  }
}

/// A full-width row — cover on the left, everything else beside it.
///
/// The same visual language as the Home rail's [WebinarCard], turned on
/// its side: cover art carrying the live and platform badges, then the
/// title, the host, and a footer pairing when-it-starts with what it
/// costs. A learner arriving here from "View All" should recognise the
/// cards they just tapped past, not meet a different design.
class _WebinarTile extends StatelessWidget {
  final WebinarItem webinar;

  const _WebinarTile({super.key, required this.webinar});

  @override
  Widget build(BuildContext context) {
    final thumbWidth = Screen.getHorizontalSize(118);
    final isLive = webinar.isLive;
    final tone = isLive ? AppColors.error : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: AppDecorations.cardBorder(
          lightColor: isLive
              ? AppColors.error.withValues(alpha: 0.30)
              : AppColors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          ...AppDecorations.cardShadow(),
          if (isLive)
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.14),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      // Inside the decorated box so the ripple is visible: wrapped
      // around it, it paints behind an opaque card and never shows.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            '${AppRoutes.webinarDetail}'
            '?slug=${Uri.encodeComponent(webinar.slug)}',
          ),
          child: Padding(
            padding: Screen.getPadding(all: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: thumbWidth,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Whole image, never a crop — same treatment
                          // as the rail card. See [WebinarCoverImage].
                          WebinarCoverImage(
                            url: webinar.thumbnailUrl,
                            fallback: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                              ),
                              child: Center(
                                child: Icon(
                                  webinar.isInPerson
                                      ? Icons.location_on_rounded
                                      : Icons.video_camera_front_outlined,
                                  color: AppColors.alwaysWhite.withValues(
                                    alpha: 0.9,
                                  ),
                                  size: Screen.getSize(22),
                                ),
                              ),
                            ),
                          ),
                          // Only over the bottom half — the badges live
                          // at the top, and dimming the whole thumbnail
                          // for them would flatten the art.
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.black.withValues(alpha: 0.30),
                                    AppColors.black.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.55],
                                ),
                              ),
                            ),
                          ),
                          if (isLive)
                            const Positioned(
                              top: 5,
                              left: 5,
                              child: WebinarLiveBadge(scale: 0.85),
                            ),
                          if (!webinar.isStream)
                            Positioned(
                              bottom: 5,
                              left: 5,
                              child: WebinarPlatformBadge(
                                platformName: webinar.platformName,
                                joinMode: webinar.joinMode,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                      SizedBox(height: Screen.getVerticalSize(6)),
                      Row(
                        children: [
                          Container(
                            width: Screen.getSize(16),
                            height: Screen.getSize(16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.10),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: Screen.getSize(10),
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Screen.getVerticalSize(10)),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: Screen.getPadding(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusS,
                                ),
                              ),
                              child: WebinarStartLabel(
                                webinar: webinar,
                                fontSize: Screen.getFontSizeCapped(11.5),
                              ),
                            ),
                          ),
                          SizedBox(width: Screen.getHorizontalSize(8)),
                          Text(
                            WebinarFormatting.price(webinar),
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: webinar.isFree
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                              fontSize: Screen.getFontSizeCapped(13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps pull-to-refresh working on the non-list states — a plain
/// [Center] isn't scrollable, so [RefreshIndicator] has nothing to catch.
class _Refreshable extends StatelessWidget {
  final Widget child;

  const _Refreshable({required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<WebinarsCubit>().load(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: constraints.maxHeight, child: child)],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String body;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor ?? AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(16),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
