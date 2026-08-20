import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/theme/branding_config.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/profile_image_viewer.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/view_demo_buy_now_row_widget.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:nexora/core/widgets/scrolling_title.dart';
import 'package:nexora/features/home/presentation/bloc/home_cubit.dart';
import 'package:nexora/features/home/presentation/widgets/banner_widget.dart';
import 'package:nexora/features/home/presentation/widgets/category_section_widget.dart';
import 'package:nexora/features/home/presentation/widgets/featured_courses_widget.dart';
import 'package:nexora/features/home/presentation/widgets/home_loading_skeleton.dart';
import 'package:nexora/features/home/presentation/widgets/reviews_section_widget.dart';
import 'package:nexora/features/home/presentation/widgets/social_media_section_widget.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_section_widget.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isSearchVisible = true;

  final GlobalKey _railKey = GlobalKey();
  double _railHeight = 0.0;
  bool _isRailHeightMeasured = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // HomeCubit and ContinueCoursesCubit are owned by the Dashboard so
    // it can silent-refresh both whenever the user re-enters the Home
    // tab; here we just kick off the initial dashboard fetch.
    context.read<HomeCubit>().loadHomeData();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRailHeight();
    });
    // The ProfileCubit is a top-level singleton. Kick off a load only when
    // it hasn't been populated yet — avoids refetching every time the
    // returns to Home, while still bootstrapping after a fresh login.
    final profileCubit = context.read<ProfileCubit>();
    final shouldLoad = profileCubit.state.maybeWhen(
      initial: () => true,
      error: (_) => true,
      orElse: () => false,
    );
    if (shouldLoad) profileCubit.loadProfile();

    // Refresh the backend's copy of the FCM token on every Home entry.
    // Fire-and-forget via `unawaited` so it never blocks the first
    // frame — `syncFcmToken` self-guards (no-ops when logged out or
    // when no token is cached) and emits no state, so a slow or failed
    // call is invisible to the user. Catches the token rotating while
    // the app sat backgrounded between Home visits.
    unawaited(profileCubit.syncFcmToken());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateRailHeight() {
    if (_railKey.currentContext != null) {
      final RenderBox? box =
          _railKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        // Always mark as measured — even when height is 0 (empty rail).
        // The old guard `box.size.height != _railHeight` prevented
        // _isRailHeightMeasured from ever flipping to true when both
        // values were 0.0, which broke the flatten animation entirely.
        if (!_isRailHeightMeasured || box.size.height != _railHeight) {
          setState(() {
            _railHeight = box.size.height;
            _isRailHeightMeasured = true;
          });
        }
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final double offset = _scrollController.offset;
      final bool shouldShowSearch = offset < 50;

      if (_isSearchVisible != shouldShowSearch) {
        setState(() {
          _isSearchVisible = shouldShowSearch;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Screen().adaptDeviceScreenSize(context);

    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return state.maybeWhen(
          initial: () => const Scaffold(body: HomeLoadingSkeleton()),
          loading: () => const Scaffold(body: HomeLoadingSkeleton()),
          loaded: (dashboard) => _buildLoadedScaffold(dashboard),
          error: (message) => Scaffold(body: _buildErrorView(message)),
          orElse: () => const Scaffold(body: SizedBox.shrink()),
        );
      },
    );
  }

  /// Loaded view returns its own [Scaffold] so the header band can
  /// sit in the [Scaffold.appBar] slot proper. The band now holds
  /// only the compact top row (avatar + welcome + icons) at a fixed
  /// height — the Continue Learning rail moved into the body so the
  /// AppBar stays a stable strip and the rail scrolls with the rest
  /// of the page content.
  Widget _buildLoadedScaffold(DashboardData dashboard) {
    final rh = ResponsiveHelper.of(context);
    // Single-row header matching the reference design: 72px tall.
    // Clamped to avoid overflow on iPads where topInset can be very tall.
    final topInset = MediaQuery.of(context).padding.top;
    // Cap band height so it never overflows — use at most 76 dp of content
    // area regardless of screen size.
    final bandHeight = topInset + 72.0;
    return Container(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(bandHeight),
          child: _HeaderBand(child: _buildHeader(dashboard)),
        ),
        body: Stack(
          children: [
            // ── 1. Scrollable Content ──
            RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: () => Future.wait([
                context.read<HomeCubit>().silentRefresh(),
                context.read<ContinueCoursesCubit>().silentRefresh(),
                context.read<WebinarsCubit>().silentRefresh(),
              ]),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics:
                    const AlwaysScrollableScrollPhysics(), // Allow pull-to-refresh even if content is short
                child: Center(
                  child: ConstrainedBox(
                    // Limit content width on tablets so it doesn't stretch
                    // across a full iPad screen (looks too sparse otherwise).
                    constraints: const BoxConstraints(
                      maxWidth: double.infinity,
                    ),
                    child: Column(
                      children: [
                        // ── Continue Purchase Rail ──
                        // Translated to visually stay fixed while the rest of the column scrolls over it.
                        // Also fades out as the white card scrolls up to the AppBar,
                        // and fades back in when the user scrolls back down.
                        AnimatedBuilder(
                          animation: _scrollController,
                          builder: (context, child) {
                            final offset = _scrollController.hasClients
                                ? _scrollController.offset
                                : 0.0;

                            // Fade zone: fully visible at offset 0,
                            // fully transparent when the white card
                            // reaches the AppBar (_railHeight).
                            // Falls back to 80 px when rail is unmeasured / empty.
                            final fadeEnd =
                                (_isRailHeightMeasured && _railHeight > 10.0)
                                ? _railHeight
                                : 250.0;
                            final railOpacity = (1.0 - (offset / fadeEnd))
                                .clamp(0.0, 1.0);

                            return Opacity(
                              opacity: railOpacity,
                              child: Transform.translate(
                                offset: Offset(0, offset > 0 ? offset : 0),
                                child: child,
                              ),
                            );
                          },
                          child:
                              BlocSelector<
                                ContinueCoursesCubit,
                                ContinueCoursesState,
                                bool
                              >(
                                selector: (state) => state.maybeWhen(
                                  loaded: (c) => c.isNotEmpty,
                                  orElse: () => false,
                                ),
                                builder: (context, hasItems) {
                                  if (!hasItems) return const SizedBox.shrink();
                                  return NotificationListener<
                                    SizeChangedLayoutNotification
                                  >(
                                    onNotification: (notification) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                            (_) => _updateRailHeight(),
                                          );
                                      return true;
                                    },
                                    child: SizeChangedLayoutNotifier(
                                      child: Container(
                                        key: _railKey,
                                        color: Colors.transparent,
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              height: Screen.getVerticalSize(
                                                15,
                                              ),
                                            ),
                                            const _ContinuePurchaseRail(),
                                            SizedBox(
                                              height: Screen.getVerticalSize(
                                                16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ),

                        // ── White content card ────────────────────────────────
                        // AnimatedBuilder drives the top-corner radius:
                        //   • Full curve (AppSizes.radiusXXL) when the card sits
                        //     in its natural resting position.
                        //   • Begins flattening 20 px before the card reaches
                        //     the AppBar (offset = _railHeight − 20).
                        //   • Fully flat (radius = 0) the moment it contacts the
                        //     AppBar (offset = _railHeight).
                        //   • Reverts smoothly when the user scrolls back down.
                        AnimatedBuilder(
                          animation: _scrollController,
                          builder: (context, child) {
                            final offset = _scrollController.hasClients
                                ? _scrollController.offset
                                : 0.0;

                            // ── Border-radius flatten zone ─────────────────────
                            // flattenStart: the EXACT scroll-offset pixel where
                            //   the animation begins. Nothing happens before this.
                            //   ↑ Increase this number to delay when it kicks in.
                            //
                            // flattenEnd: the scroll-offset pixel where the corners
                            //   are fully flat (radius = 0). This should roughly
                            //   match when the white card reaches the AppBar.
                            //   Use _railHeight when measured, else a safe default.
                            //
                            // Both values are INDEPENDENT of each other — tuning
                            // flattenStart never affects flattenEnd.
                            const double flattenStart =
                                200.0; // ← change this only
                            final double flattenEnd =
                                (_isRailHeightMeasured &&
                                    _railHeight > flattenStart)
                                ? _railHeight // card measured → use it
                                : flattenStart + 80.0; // fallback: 80 px window

                            final progress =
                                ((offset - flattenStart) /
                                        (flattenEnd - flattenStart))
                                    .clamp(0.0, 1.0);

                            // When there are no continue-courses the white card
                            // sits flush against the AppBar from offset=0, so
                            // always show flat corners. When courses exist,
                            // animate from full curve → flat as the user scrolls.
                            final hasContinueCourses = context
                                .read<ContinueCoursesCubit>()
                                .state
                                .maybeWhen(
                                  loaded: (c) => c.isNotEmpty,
                                  orElse: () => false,
                                );

                            final currentRadius = hasContinueCourses
                                ? lerpDouble(AppSizes.radiusXXL, 0.0, progress)!
                                : 0.0;

                            return Container(
                              width: Screen.width,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(currentRadius),
                                  topRight: Radius.circular(currentRadius),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: ConstrainedBox(
                            // minHeight = full device screen height so the white
                            // card always extends far enough to be scrollable /
                            // draggable upward, regardless of visible sections.
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: Screen.getVerticalSize(25)),
                                BannerSection(banners: dashboard.banner),
                                // Above the course rails on purpose: a
                                // webinar is time-bound, and one that is
                                // live right now is the most perishable
                                // thing on this screen. Renders nothing
                                // when the org runs no webinars.
                                const WebinarSectionWidget(),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                FeaturedCoursesWidget(
                                  title: 'New Courses',
                                  showNewBadge: true,
                                  viewAllRoute:
                                      '${AppRoutes.catalog}?sortBy=new',
                                  courses: dashboard.newCourses
                                      .map(
                                        (c) => CourseCardData(
                                          courseId: c.courseId,
                                          courseTitle: c.courseTitle,
                                          courseImageUrl: c.courseImageUrl,
                                          rating: c.rating,
                                          totalReviewsCounts:
                                              c.totalReviewsCounts,
                                        ),
                                      )
                                      .toList(),
                                ),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                CategorySection(tiles: dashboard.educatorTiles),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                FeaturedCoursesWidget(
                                  title: 'Trending Courses',
                                  viewAllRoute:
                                      '${AppRoutes.catalog}?sortBy=trending',
                                  courses: dashboard.trendingCourses
                                      .map(
                                        (c) => CourseCardData(
                                          courseId: c.courseId,
                                          courseTitle: c.courseTitle,
                                          courseImageUrl: c.courseImageUrl,
                                          rating: c.rating,
                                          totalReviewsCounts:
                                              c.totalReviewsCounts,
                                        ),
                                      )
                                      .toList(),
                                ),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                ReviewsSectionWidget(
                                  reviews: dashboard.learnerReviews,
                                ),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                SocialMediaSectionWidget(
                                  links: dashboard.socialMediaLinks,
                                ),
                                SizedBox(height: Screen.getVerticalSize(25)),
                                Utils.defaultBottomSpace(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 2. Locked Top Rounded Corners Overlay ──
            // Becomes visible only when the white card has scrolled up to the AppBar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final threshold = _isRailHeightMeasured
                      ? _railHeight
                      : 9999.0;

                  if (offset >= threshold) {
                    return Container(
                      height:
                          40, // Tall enough to draw the full radius seamlessly
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(AppSizes.radiusXXL),
                          topRight: Radius.circular(AppSizes.radiusXXL),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AppBar content — single-row layout matching the reference design:
  ///   Left : large avatar + "Hello, [name]" (bold) / "Welcome to Crinza" (muted)
  Widget _buildHeader(DashboardData dashboard) {
    return Padding(
      padding: Screen.getPadding(left: 16, right: 16, top: 12, bottom: 12),
      child: BlocSelector<ProfileCubit, ProfileState, UserProfileModel?>(
        selector: (state) => state.maybeWhen(
          loaded: (p) => p,
          updated: (p) => p,
          updating: (p) => p,
          orElse: () => null,
        ),
        builder: (context, profile) {
          final imageUrl = profile?.userProfileImage;
          final name = profile?.name ?? '';
          final initials = Utils.getInitials(name.isEmpty ? '?' : name);
          final displayName = name.isNotEmpty ? name : '—';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar ───────────────────────────────────────────
              // Shows the user's network image when available;
              // otherwise renders their initials on a gradient circle.
              // Tapping the image opens the full-screen zoomable viewer;
              // the hero flight only applies when there is an image to fly.
              GestureDetector(
                onTap: (imageUrl != null && imageUrl.isNotEmpty)
                    ? () => showProfileImageViewer(context, imageUrl: imageUrl)
                    : null,
                child: ProfileImageHero(
                  tag: (imageUrl != null && imageUrl.isNotEmpty)
                      ? kProfileImageHeroTag
                      : null,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? CircleAvatar(
                          radius: 26,
                          backgroundImage: CachedNetworkImageProvider(
                            imageUrl,
                            cacheKey: Utils.imageCacheKey(imageUrl),
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.alwaysWhite.withValues(alpha: 0.35),
                                AppColors.alwaysWhite.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppColors.alwaysWhite.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: AppTypography.h6SemiBold.copyWith(
                              color: AppColors.alwaysWhite,
                              fontSize: Screen.getFontSize(16),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Greeting text ────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScrollingTitle(
                      text: 'Hello, $displayName',
                      style: AppTypography.h6SemiBold.copyWith(
                        fontSize: Screen.getFontSizeCapped(16),
                        color: AppColors.alwaysWhite,
                        height: 1.2,
                      ),
                    ),
                    RichScrollingTitle(
                      span: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Welcome to ',
                            style: AppTypography.bodyTextMedium.copyWith(
                              color: Colors.white60,
                              fontSize: Screen.getFontSizeCapped(12),
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: currentBranding.appName,
                            style: AppTypography.h6SemiBold.copyWith(
                              color: AppColors.alwaysWhite,
                              fontSize: Screen.getFontSizeCapped(12),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Icons ────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    assetPath: AppImages.searchIcon,
                    onTap: () => context.push(AppRoutes.courseSearch),
                  ),
                  _NotificationBell(
                    count: dashboard.notificationCount,
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingL).top),
          const Text('Something went wrong'),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingS).top),
          Text(message),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingL).top),
          CustomActionButton(
            onTap: (startLoading, stopLoading, isSuccess) {
              startLoading();
              Future.delayed(const Duration(seconds: 2), () {
                stopLoading();
                if (!mounted) return;
                context.read<HomeCubit>().loadHomeData();
              });
            },
            isFormFilled: true,
            name: 'Retry',
          ),
        ],
      ),
    );
  }
}

/// AppBar-style coloured band that sits behind the home header.
///
/// Replaces the previous full-screen DecorationImage backdrop. Uses
/// `AppColors.primary` with two opacity stops so the band reads as a
/// subtle gradient — top crisp, bottom slightly softened — without
/// needing an image asset. The SafeArea inside makes the band hug the
/// status bar on every device while leaving the content padded.
class _HeaderBand extends StatelessWidget {
  final Widget child;

  const _HeaderBand({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient, // Hot pink → soft lavender
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

/// Header icon button — used for both the search and notification bell
/// taps. Renders a 24-pt PNG asset tinted white so it sits cleanly on
/// the coloured header band.
class _HeaderIconButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.assetPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Image.asset(
        assetPath,
        width: 24,
        height: 24,
        color: AppColors.alwaysWhite,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// A read-only field-shaped tap target that mimics the look of the
/// course-search input but pushes the dedicated [SearchPage] instead of
/// taking input. Currently unused — the search bar is commented out and
/// the search icon button next to the bell handles the navigation. Kept
/// in the file so it's a one-line change to restore the inline field.
// ignore: unused_element
class _SearchTrigger extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchTrigger({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: Screen.getVerticalSize(50),
        padding: EdgeInsets.symmetric(horizontal: Screen.getHorizontalSize(16)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
          border: AppDecorations.cardBorder(),
          boxShadow: AppDecorations.cardShadow(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Find your courses here',
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ),
            Icon(Icons.search, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.alwaysWhite,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.error,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      alignment: Alignment.topRight,
      child: IconButton(
        onPressed: onTap,
        icon: Image.asset(
          AppImages.notificationIcon,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          color: AppColors.alwaysWhite,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Premium "Continue your purchase" rail with gradient card design.
/// Features a rich gradient background, animated shine, urgency badge,
/// and professional card layout that stands out on the home screen.
class _ContinuePurchaseRail extends StatelessWidget {
  const _ContinuePurchaseRail();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinueCoursesCubit, ContinueCoursesState>(
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) {
        final courses = state.maybeWhen(
          loaded: (c) => c,
          orElse: () => <CourseSummary>[],
        );
        if (courses.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: Screen.getPadding(horizontal: 16, top: 1, bottom: 4),
          child: _ContinuePurchaseSection(courses: courses),
        );
      },
    );
  }
}

class _ContinuePurchaseSection extends StatefulWidget {
  final List<CourseSummary> courses;

  const _ContinuePurchaseSection({required this.courses});

  @override
  State<_ContinuePurchaseSection> createState() =>
      _ContinuePurchaseSectionState();
}

class _ContinuePurchaseSectionState extends State<_ContinuePurchaseSection> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start at a large multiple of courses.length to allow infinite scrolling in both directions
    final initialPage = widget.courses.isNotEmpty
        ? 1000 * widget.courses.length
        : 0;
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);

    if (widget.courses.length > 1) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.primary.withValues(alpha: 0.47);
    final innerColor = AppColors.primary.withValues(alpha: 0.12);

    final realIndex = widget.courses.isNotEmpty
        ? _currentPage % widget.courses.length
        : 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card surface — solid white + gradient border.
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: radius,
              border: GradientBorder(
                gradient: LinearGradient(
                  colors: [borderLow, borderMid, borderLow],
                ),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Padding(
                padding: Screen.getPadding(horizontal: 14, top: 12, bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: title + page counter
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: AppColors.primary,
                              size: Screen.getFontSize(16),
                            ),
                            SizedBox(width: Screen.getHorizontalSize(8)),
                            Text(
                              "You're One Step Away!",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: Screen.getFontSize(14),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (widget.courses.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Text(
                              '${realIndex + 1}/${widget.courses.length}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: Screen.getFontSize(11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: Screen.getVerticalSize(10)),

                    // Course cards PageView
                    // Height is capped at 250 dp so it doesn't grow
                    // excessively on wide screens but is tall enough for iPad/Fold.
                    SizedBox(
                      height: Screen.getVerticalSize(140).clamp(0.0, 250.0),
                      child: PageView.builder(
                        pageSnapping: true,
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (i) {
                          setState(() => _currentPage = i);
                          if (widget.courses.length > 1) {
                            _startAutoScroll(); // restart timer on manual swipe
                          }
                        },
                        itemBuilder: (_, index) {
                          final courseIndex = widget.courses.isEmpty
                              ? 0
                              : index % widget.courses.length;
                          return _ContinuePurchaseCard(
                            course: widget.courses[courseIndex],
                          );
                        },
                      ),
                    ),

                    // Dot indicators
                    if (widget.courses.length > 1) ...[
                      SizedBox(height: Screen.getVerticalSize(8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.courses.length, (i) {
                          final isActive = i == realIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            margin: EdgeInsets.symmetric(
                              horizontal: Screen.getHorizontalSize(3),
                            ),
                            width: Screen.getHorizontalSize(isActive ? 18 : 5),
                            height: Screen.getVerticalSize(5),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Inner shadow overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: InnerShadowPainter(
                  color: innerColor,
                  blurRadius: 54,
                  offset: const Offset(0, 4),
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Course card inside the "Continue your purchase" PageView.
/// Thumbnail left, title + Buy Now right, button pinned to bottom.
class _ContinuePurchaseCard extends StatelessWidget {
  final CourseSummary course;

  const _ContinuePurchaseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final borderLow = AppColors.primary.withValues(alpha: 0.12);
    final borderMid = AppColors.secondary.withValues(alpha: 0.47);
    final borderHigh = AppColors.primary.withValues(alpha: 0.12);
    final innerColor = AppColors.secondary.withValues(alpha: 0.10);

    return GestureDetector(
      // Tap anywhere on the card → course detail page.
      // The Buy Now button row intercepts its own taps below,
      // so they never bubble up here.
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.push('${AppRoutes.courseDetail}?courseId=${course.courseId}'),
      child: Container(
        margin: EdgeInsets.only(right: Screen.getHorizontalSize(8)),
        decoration: BoxDecoration(borderRadius: radius),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: radius,
                border: GradientBorder(
                  gradient: LinearGradient(
                    colors: [borderLow, borderMid, borderHigh],
                  ),
                  width: 1.5,
                ),
              ),
              // No ClipRRect here — it was clipping the Buy Now button
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Thumbnail (45% width, 6px margin) ─────────────────
                  Expanded(
                    flex: 45,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: CustomNetworkImage(
                          url: course.courseImageUrl,
                          borderRadius: BorderRadius.zero,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppColors.grey100,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.grey400,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Info column (55% width): title top, button bottom ────
                  Expanded(
                    flex: 55,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: Screen.getHorizontalSize(6),
                        right: Screen.getHorizontalSize(6),
                        top: Screen.getVerticalSize(6),
                        bottom: Screen.getVerticalSize(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Course title (takes all remaining height)
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                course.courseTitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: Screen.getFontSizeCapped(14),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),

                          // Buy Now button — wrapped in a GestureDetector
                          // that absorbs taps so they do NOT bubble up to
                          // the card-level navigator above.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap:
                                () {}, // absorb — ViewDemoBuyNowRow handles its own taps internally
                            child: ViewDemoBuyNowRow(
                              courseId: course.courseId,
                              showViewDetails: false,
                              showViewDemo: false,
                              showBuyNow: true,
                              buttonHeight: 50,
                              onPurchased: () => context
                                  .read<ContinueCoursesCubit>()
                                  .removeCourse(course.courseId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Inner shadow overlay
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InnerShadowPainter(
                    color: innerColor,
                    blurRadius: 30,
                    offset: const Offset(0, 4),
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
