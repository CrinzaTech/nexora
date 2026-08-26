import 'package:flutter/services.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/live_now_cubit.dart';
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

class _DashboardPageState extends State<DashboardPage> {
  late final PageController _pageController;
  late final List<Widget> _pages;
  // Held here (not inside the page list) so [_onNavSelected] can fire a
  // silent refresh whenever the user re-enters the Home tab — otherwise
  // the page's [AutomaticKeepAliveClientMixin] keeps it alive and its
  // initState (the only existing fetch hook) never re-runs.
  late final HomeCubit _homeCubit;
  late final ContinueCoursesCubit _continueCubit;
  late final LiveNowCubit _liveNowCubit;
  // Owned here for the same reason as the two above — the Home rail has
  // to pick up a webinar that went live while the learner was on another
  // tab, and HomePage's keep-alive means its initState never re-runs.
  late final WebinarsCubit _webinarsCubit;
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  // Navigation items for the bottom navbar
  final List<NavItem> _navItems = const [
    NavItem(
      label: 'Home',
      icon: AppImages.homeUnselectedIcon,
      activeIcon: AppImages.homeSelectedIcon,
      route: 'home',
    ),
    NavItem(
      label: 'Chats',
      icon: AppImages.chatUnselectedIcon,
      activeIcon: AppImages.chatSelectedIcon,
      route: 'chats',
    ),
    NavItem(
      label: 'Courses',
      icon: AppImages.courseUnselectedIcon,
      activeIcon: AppImages.courseSelectedIcon,
      route: 'courses',
    ),
    NavItem(
      label: 'Profile',
      icon: AppImages.profileUnselectedIcon,
      activeIcon: AppImages.profileSelectedIcon,
      route: 'profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    _homeCubit = sl<HomeCubit>();
    _continueCubit = sl<ContinueCoursesCubit>()..load();
    // Gathers its own schedule (a request per owned course) and then
    // re-checks it locally, so it is started once here rather than on
    // every entry to the Home tab.
    _liveNowCubit = sl<LiveNowCubit>()..load();
    _webinarsCubit = sl<WebinarsCubit>()..load();

    // Cache pages once to avoid recreating BlocProviders on every build.
    // Both cubits are owned here (provided via .value) so [_onNavSelected]
    // can talk to them directly when re-entering Home.
    _pages = [
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _homeCubit),
          BlocProvider.value(value: _continueCubit),
          BlocProvider.value(value: _liveNowCubit),
          BlocProvider.value(value: _webinarsCubit),
        ],
        child: const HomePage(key: ValueKey('home')),
      ),
      const ChatsPage(key: ValueKey('chats')),
      const MyCoursesPage(key: ValueKey('courses')),
      const ProfilePage(key: ValueKey('profile')),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeCubit.close();
    _continueCubit.close();
    _liveNowCubit.close();
    _webinarsCubit.close();
    super.dispose();
  }

  /// Handle navigation item tap
  void _onNavSelected(String route) {
    final index = _navItems.indexWhere((item) => item.route == route);
    if (index != -1 && index != _currentIndex) {
      _pageController.jumpToPage(index);
      setState(() => _currentIndex = index);
      // Silent refresh on re-entering Home so dashboard data
      // (learner reviews) and the Continue Learning rail stay fresh
      // without flashing loading skeletons.
      if (index == 0) {
        _homeCubit.silentRefresh();
        _continueCubit.silentRefresh();
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
  final Widget bottomNavBar;
  final List<Widget> children;

  const _PageViewWithNavBar({
    required this.pageController,
    required this.bottomNavBar,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: pageController,
          children: children,
        ),

        /// Floating Navbar
        Positioned(
          left: Screen.getHorizontalSize(20),
          right: Screen.getHorizontalSize(20),
          bottom: Screen.getVerticalSize(0),
          child: SafeArea(child: bottomNavBar),
        ),
      ],
    );
  }
}
