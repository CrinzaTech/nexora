import 'package:flutter/services.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/payment_policy.dart';
import 'package:nexora/core/services/app_link_service.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/features/home_live/presentation/bloc/home_live_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/home/presentation/bloc/home_cubit.dart';
import 'package:nexora/features/home/presentation/pages/home_page.dart';
import 'package:nexora/features/chats/presentation/pages/chats_page.dart';
import 'package:nexora/features/courses/presentation/pages/my_courses_page.dart';
import 'package:nexora/features/profile/presentation/pages/profile_page.dart';
import 'package:nexora/features/dashboard/presentation/widgets/floating_navbar.dart';

/// Dashboard Screen
/// Main app screen with PageView for content navigation and FloatingNavbar
class DashboardPage extends StatefulWidget {
  /// Optional initial index for deep linking (0-3)
  final int initialIndex;

  const DashboardPage({super.key, this.initialIndex = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final List<Widget> _pages;
  // Held here (not inside the page list) so [_onNavSelected] can fire a
  // silent refresh whenever the user re-enters the Home tab — otherwise
  // the page's [AutomaticKeepAliveClientMixin] keeps it alive and its
  // initState (the only existing fetch hook) never re-runs.
  late final HomeCubit _homeCubit;
  late final ContinueCoursesCubit _continueCubit;
  // The "Live classes" rail: served by its own endpoint, refreshed on
  // every return to Home so a class that went live meanwhile shows its
  // badge without a restart.
  late final HomeLiveCubit _homeLiveCubit;
  // Owned here for the same reason as the two above — the Home rail has
  // to pick up a webinar that went live while the learner was on another
  // tab, and HomePage's keep-alive means its initState never re-runs.
  late final WebinarsCubit _webinarsCubit;
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  // The navbar hides when the learner scrolls down and returns when they
  // scroll up — a timed animation of its own, started after a short delay,
  // not tied to the scroll position. 0 = shown, 1 = hidden.
  late final AnimationController _navHidden;

  /// How far the bar travels to be off-screen: its height plus the safe
  /// area under it.
  static const double _navTravel = 140;

  /// The bar starts moving the moment the scroll direction is clear — no
  /// wait — and glides for exactly [_navSettleDuration]. That is fixed: the
  /// bar takes the same time to hide or show however fast the page is being
  /// scrolled, because the animation never reads the scroll speed.
  static const Duration _navSettleDuration = Duration(milliseconds: 350);

  /// Where the bar is heading, so a steady scroll doesn't restart the
  /// animation on every notification.
  bool _navTargetHidden = false;

  /// Scroll travelled in the current direction. The bar only flips after a
  /// deliberate stretch, so a small wobble doesn't trigger it.
  double _scrollRun = 0;
  static const double _scrollToggleDistance = 6;

  // Navigation items for the bottom navbar
  final List<NavItem> _navItems = [
    const NavItem(
      label: 'Home',
      icon: AppImages.homeUnselectedIcon,
      activeIcon: AppImages.homeSelectedIcon,
      route: 'home',
    ),
    const NavItem(
      label: 'Chats',
      icon: AppImages.chatUnselectedIcon,
      activeIcon: AppImages.chatSelectedIcon,
      route: 'chats',
    ),
    NavItem(
      // "Enrolled" implies a sign-up/purchase step iOS doesn't offer
      // (see PaymentPolicy).
      label: PaymentPolicy.allowsPurchases ? 'Enrolled' : 'Courses',
      icon: AppImages.courseUnselectedIcon,
      activeIcon: AppImages.courseSelectedIcon,
      route: 'courses',
    ),
    const NavItem(
      label: 'Profile',
      icon: AppImages.profileUnselectedIcon,
      activeIcon: AppImages.profileSelectedIcon,
      route: 'profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _navHidden = AnimationController(vsync: this, duration: _navSettleDuration);
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    _homeCubit = sl<HomeCubit>();
    _continueCubit = sl<ContinueCoursesCubit>()..load();
    _homeLiveCubit = sl<HomeLiveCubit>()..load();
    _webinarsCubit = sl<WebinarsCubit>()..load();

    // Cache pages once to avoid recreating BlocProviders on every build.
    // Both cubits are owned here (provided via .value) so [_onNavSelected]
    // can talk to them directly when re-entering Home.
    _pages = [
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _homeCubit),
          BlocProvider.value(value: _continueCubit),
          BlocProvider.value(value: _homeLiveCubit),
          BlocProvider.value(value: _webinarsCubit),
        ],
        child: const HomePage(key: ValueKey('home')),
      ),
      const ChatsPage(key: ValueKey('chats')),
      const MyCoursesPage(key: ValueKey('courses')),
      const ProfilePage(key: ValueKey('profile')),
    ];

    // A shared course link that arrived before there was a dashboard to
    // push onto — cold start, signed out, or a fresh install — opens now.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppLinkService.consumePending(),
    );
  }

  @override
  void dispose() {
    _navHidden.dispose();
    _pageController.dispose();
    _homeCubit.close();
    _continueCubit.close();
    _homeLiveCubit.close();
    _webinarsCubit.close();
    super.dispose();
  }

  void _setNavHidden(bool hidden) {
    if (_navTargetHidden == hidden) return;
    _navTargetHidden = hidden;
    if (!mounted) return;
    _navHidden.animateTo(
      hidden ? 1 : 0,
      duration: _navSettleDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  bool _onPageScroll(ScrollNotification n) {
    // Only the pages' own vertical scrolling counts — not the banner /
    // rails sliding sideways.
    if (n is! ScrollUpdateNotification || n.metrics.axis != Axis.vertical) {
      return false;
    }
    if (n.metrics.pixels <= 0) {
      // At (or pulled past) the top the bar is always out.
      _scrollRun = 0;
      _setNavHidden(false);
      return false;
    }
    // Past the end of the content (the iOS bounce at the bottom) the
    // scroll springs back the other way. That isn't the learner scrolling
    // up, so it must not bring the bar back.
    if (n.metrics.outOfRange) return false;
    final delta = n.scrollDelta ?? 0;
    if (delta == 0) return false;
    // A change of direction starts a fresh run.
    if ((delta > 0) != (_scrollRun > 0)) _scrollRun = 0;
    _scrollRun += delta;
    if (_scrollRun > _scrollToggleDistance) {
      _setNavHidden(true);
    } else if (_scrollRun < -_scrollToggleDistance) {
      _setNavHidden(false);
    }
    return false;
  }

  /// Handle navigation item tap
  void _onNavSelected(String route) {
    final index = _navItems.indexWhere((item) => item.route == route);
    if (index != -1 && index != _currentIndex) {
      _pageController.jumpToPage(index);
      _setNavHidden(false);
      setState(() => _currentIndex = index);
      // Silent refresh on re-entering Home so dashboard data
      // (learner reviews) and the Continue Learning rail stay fresh
      // without flashing loading skeletons.
      if (index == 0) {
        _homeCubit.silentRefresh();
        _continueCubit.silentRefresh();
        _homeLiveCubit.silentRefresh();
        _webinarsCubit.silentRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          _onNavSelected('home');
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.grey50,
        body: _PageViewWithNavBar(
          pageController: _pageController,
          navHidden: _navHidden,
          navTravel: _navTravel,
          onScroll: _onPageScroll,
          bottomNavBar: FloatingNavbar(
            items: _navItems,
            activeRoute: _navItems[_currentIndex].route,
            onDestinationSelected: _onNavSelected,
          ),
          children: _pages,
        ),
      ),
    );
  }
}

/// PageView with floating navbar overlay
class _PageViewWithNavBar extends StatelessWidget {
  final PageController pageController;
  final Animation<double> navHidden;
  final double navTravel;
  final bool Function(ScrollNotification) onScroll;
  final Widget bottomNavBar;
  final List<Widget> children;

  const _PageViewWithNavBar({
    required this.pageController,
    required this.navHidden,
    required this.navTravel,
    required this.onScroll,
    required this.bottomNavBar,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: PageView(
            physics: const NeverScrollableScrollPhysics(),
            controller: pageController,
            children: children,
          ),
        ),

        /// Floating Navbar
        Positioned(
          left: Screen.getHorizontalSize(20),
          right: Screen.getHorizontalSize(20),
          bottom: Screen.getVerticalSize(0),
          child: AnimatedBuilder(
            animation: navHidden,
            builder: (context, child) => IgnorePointer(
              // Not tappable once it is more than half gone.
              ignoring: navHidden.value > 0.5,
              child: Transform.translate(
                offset: Offset(0, navHidden.value * navTravel),
                child: Opacity(opacity: 1 - navHidden.value, child: child),
              ),
            ),
            child: SafeArea(child: bottomNavBar),
          ),
        ),
      ],
    );
  }
}
