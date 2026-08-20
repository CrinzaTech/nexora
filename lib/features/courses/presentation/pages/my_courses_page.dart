import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:nexora/features/certificate/presentation/certificate_download_action.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/my_courses_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_images.dart';

/// Bottom padding each tab's list reserves so the last card clears the
/// floating navbar. Mirrors `Utils.defaultBottomSpace`'s height, but as
/// scroll padding instead of a widget — the navbar is translucent glass,
/// so the space behind it has to be scrollable content, not an opaque
/// spacer sitting outside the scroll view.
const double _navBarClearance = kBottomNavigationBarHeight + 75;

/// My Courses screen — splits the user's purchased courses into
/// `In Progress` (still being watched) and `Completed` (100% done or
/// past their access window) tabs. Powered by [MyCoursesCubit].
///
/// The search action in the AppBar toggles a local filter (mirrors the
/// pattern in [ChatsPage]); the filter applies to whichever tab is
/// active and matches against the course title case-insensitively.
class MyCoursesPage extends StatefulWidget {
  const MyCoursesPage({super.key});

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Mirror of `_searchController.text.trim().toLowerCase()` so the
  /// build doesn't re-run `toLowerCase` on every paint.
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _query = '';
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  /// Search row height — must match the padded [_MyCoursesSearchBar] exactly.
  /// A pinned sliver reports a fixed extent, so any mismatch either leaves a
  /// white gap or lets the child overflow behind the list.
  double get _searchRowExtent =>
      Screen.getVerticalSize(12) +
      Screen.getVerticalSize(46) +
      Screen.getVerticalSize(8);

  /// TabBar's intrinsic height (46) plus its 1px divider, rounded up.
  /// Unscaled because the TabBar sizes itself, not via [Screen].
  static const double _tabRowExtent = 48;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Screen().adaptDeviceScreenSize(context);
    // ignore: unused_local_variable
    final rh = ResponsiveHelper.of(context);
    return BlocProvider(
      create: (_) => sl<MyCoursesCubit>()..load(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: NestedScrollView(
            // Required for [SliverAppBar.floating]/[snap] to actually drive
            // the header. Without it NestedScrollView treats a floating bar
            // as pinned: the title never scrolls away, and the app bar's
            // `bottom` slides out of sync with the body viewport, which is
            // what let list cards paint over the tab indicator.
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // Title row — scrolls fully out of view on scroll-down and
                // snaps back on the first upward flick. It cannot be pinned
                // here: a pinned SliverAppBar always reserves its toolbar
                // height, so the title could never hide.
                SliverAppBar(
                  backgroundColor: AppColors.white,
                  surfaceTintColor: AppColors.white,
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  snap: true,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  titleSpacing: Screen.getHorizontalSize(20),
                  title: Text(
                    'My Courses',
                    style: AppTypography.h5SemiBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: Screen.getFontSizeCapped(18),
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: _isSearching ? 'Close search' : 'Search',
                      onPressed: _toggleSearch,
                      icon: _isSearching
                          ? Icon(Icons.close, color: AppColors.textPrimary)
                          : Image.asset(
                              AppImages.searchIcon,
                              width: Screen.getSize(20),
                              height: Screen.getSize(20),
                              color: AppColors.textPrimary,
                            ),
                    ),
                    SizedBox(width: Screen.getHorizontalSize(8)),
                  ],
                ),

                // Tabs (plus the search field when active) stay pinned to the
                // top for the whole scroll. Split out of the app bar's
                // `bottom` so it survives the title collapsing away.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MyCoursesTabHeader(
                    extent:
                        (_isSearching ? _searchRowExtent : 0) + _tabRowExtent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSearching)
                          Padding(
                            padding: Screen.getPadding(
                              horizontal: 20,
                              top: 12,
                              bottom: 8,
                            ),
                            child: _MyCoursesSearchBar(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              hintText: 'Search my courses',
                              onChanged: (_) => _onQueryChanged(),
                              onClear: () {
                                _searchController.clear();
                                _onQueryChanged();
                              },
                            ),
                          ),
                        Padding(
                          padding: Screen.getPadding(horizontal: 15),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.mutedTextPrimary
                                .withValues(alpha: 0.5),
                            labelStyle: AppTypography.bodyTextLargeSemiBold
                                .copyWith(
                                  fontSize: Screen.getFontSizeCapped(15),
                                ),
                            unselectedLabelStyle: AppTypography
                                .bodyTextLargeMedium
                                .copyWith(
                                  fontSize: Screen.getFontSizeCapped(15),
                                ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2.5,
                              ),
                            ),
                            dividerColor: AppColors.mutedTextPrimary.withValues(
                              alpha: 0.15,
                            ),
                            tabs: const [
                              Tab(text: 'In Progress'),
                              Tab(text: 'Completed'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            // The navbar clearance lives in each tab's list padding rather
            // than as a sibling spacer — a spacer here would paint a solid
            // opaque band under the glass navbar instead of letting the
            // cards scroll beneath it.
            body: TabBarView(
              controller: _tabController,
              children: [
                _InProgressTab(query: _query),
                _CompletedTab(query: _query),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed-height pinned header holding the tabs (and the search field when
/// it's open). Min and max extent are equal — this header doesn't shrink,
/// it just stays put while the title bar above it scrolls away.
class _MyCoursesTabHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _MyCoursesTabHeader({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Opaque so list cards scrolling underneath stay hidden.
    return Container(color: AppColors.white, height: extent, child: child);
  }

  @override
  bool shouldRebuild(_MyCoursesTabHeader oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}

class _MyCoursesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MyCoursesSearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Screen.getVerticalSize(46),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: Screen.getHorizontalSize(16)),
          Icon(
            Icons.search,
            color: AppColors.mutedTextPrimary,
            size: Screen.getSize(20),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.grey400,
                  fontSize: Screen.getFontSize(14),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
          // Clear button — only visible when there is text.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Screen.getHorizontalSize(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedTextPrimary,
                    size: Screen.getSize(18),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isNotEmpty) return const SizedBox.shrink();
              return SizedBox(width: Screen.getHorizontalSize(16));
            },
          ),
        ],
      ),
    );
  }
}

/// Local filter — case-insensitive match on the course title only.
List<CourseSummary> _applyQuery(List<CourseSummary> list, String query) {
  if (query.isEmpty) return list;
  return list
      .where((c) => c.courseTitle.toLowerCase().contains(query))
      .toList();
}

/// Wraps a non-list state (empty / error / "no matches") so pull-to-refresh
/// still works. A plain [Center] isn't scrollable, so [RefreshIndicator]
/// has nothing to catch; we layer a [SingleChildScrollView] with
/// [AlwaysScrollableScrollPhysics] and pin the child to the full viewport
/// so it stays visually centred.
class _RefreshableEmpty extends StatelessWidget {
  final Widget child;

  const _RefreshableEmpty({required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<MyCoursesCubit>().load(),
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

// ───────────────────────────────────────────────────────────────────
// In Progress tab — purchased courses with completion < 100%.
// ───────────────────────────────────────────────────────────────────
class _InProgressTab extends StatelessWidget {
  final String query;

  const _InProgressTab({required this.query});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCoursesCubit, MyCoursesState>(
      builder: (context, state) {
        return state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _RefreshableEmpty(
            child: _EmptyState(
              icon: Icons.error_outline,
              message: message,
              iconColor: AppColors.error,
            ),
          ),
          loaded: (courses) {
            final base = courses
                .where((c) => c.isPurchased && !c.isCompleted)
                .toList();
            // Empty source → friendly empty state. Empty *because of the
            // query* → distinct "no matches" copy so the user knows it's
            // their search, not the data.
            if (base.isEmpty) {
              return const _RefreshableEmpty(
                child: _EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: "You haven't enrolled in any courses yet.",
                ),
              );
            }
            final list = _applyQuery(base, query);
            if (list.isEmpty) {
              return _RefreshableEmpty(child: _NoSearchResults(query: query));
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<MyCoursesCubit>().load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Screen.getPadding(
                  horizontal: 20,
                  top: 16,
                ).copyWith(bottom: _navBarClearance),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: Screen.getVerticalSize(14)),
                itemBuilder: (_, i) => _InProgressCard(course: list[i]),
              ),
            );
          },
          orElse: () => const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Completed tab — purchased courses with completion ≥ 100%, split
// visually by access state (active access vs. expired).
// ───────────────────────────────────────────────────────────────────
class _CompletedTab extends StatelessWidget {
  final String query;

  const _CompletedTab({required this.query});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCoursesCubit, MyCoursesState>(
      builder: (context, state) {
        return state.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _RefreshableEmpty(
            child: _EmptyState(
              icon: Icons.error_outline,
              message: message,
              iconColor: AppColors.error,
            ),
          ),
          loaded: (courses) {
            final base = courses
                .where((c) => c.isPurchased && c.isCompleted)
                .toList();
            if (base.isEmpty) {
              return const _RefreshableEmpty(
                child: _EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: 'No completed courses yet.\nKeep learning!',
                ),
              );
            }
            final list = _applyQuery(base, query);
            if (list.isEmpty) {
              return _RefreshableEmpty(child: _NoSearchResults(query: query));
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<MyCoursesCubit>().load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Screen.getPadding(
                  horizontal: 20,
                  top: 16,
                ).copyWith(bottom: _navBarClearance),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: Screen.getVerticalSize(14)),
                itemBuilder: (_, i) => _CompletedCard(course: list[i]),
              ),
            );
          },
          orElse: () => const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Shared: card chrome (thumbnail row + bottom CTA inside a rounded
// border). The two tab variants only differ in the middle section
// (progress vs. access status) and the CTA copy/colour.
// ───────────────────────────────────────────────────────────────────
class _CourseCardShell extends StatelessWidget {
  final CourseSummary course;
  final Widget middle;
  final Widget action;

  const _CourseCardShell({
    required this.course,
    required this.middle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(all: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: AppDecorations.cardBorder(
          lightColor: AppColors.mutedTextPrimary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: CustomNetworkImage(
                  url: course.courseImageUrl,
                  width: Screen.getHorizontalSize(100),
                  height: Screen.getVerticalSize(100),
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    width: Screen.getHorizontalSize(100),
                    height: Screen.getVerticalSize(100),
                    color: AppColors.grey100,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.grey300,
                    ),
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h5SemiBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: Screen.getFontSize(14),
                        height: 1.3,
                      ),
                    ),
                    if (course.categoryName != null ||
                        course.contentCount != null) ...[
                      SizedBox(height: Screen.getVerticalSize(6)),
                      Text(
                        _buildSubtitle(course),
                        style: AppTypography.bodyTextMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                          fontSize: Screen.getFontSize(13),
                        ),
                      ),
                    ],
                    SizedBox(height: Screen.getVerticalSize(10)),
                    middle,
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(15)),
          action,
        ],
      ),
    );
  }

  /// "UPSC Exams · 6 Modules" — drops empty parts so courses missing a
  /// category or module count still render a clean line.
  static String _buildSubtitle(CourseSummary c) {
    final parts = <String>[
      if (c.categoryName != null && c.categoryName!.isNotEmpty) c.categoryName!,
      if (c.contentCount != null) '${c.contentCount} Modules',
    ];
    return parts.join(' • ');
  }
}

// ───────────────────────────────────────────────────────────────────
// In Progress card — progress bar + "Resume Watching".
// ───────────────────────────────────────────────────────────────────
class _InProgressCard extends StatelessWidget {
  final CourseSummary course;

  const _InProgressCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final progress = course.progressRatio;
    final progressLabel = course.progressLabel;

    return _CourseCardShell(
      course: course,
      middle: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Text(
            progressLabel,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.primary,
              fontSize: Screen.getFontSize(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      action: CustomActionButton(
        name: 'Resume Watching',
        isFormFilled: true,
        onTap: (_, __, ___) => context.push(
          '${AppRoutes.courseDetail}?courseId=${course.courseId}',
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Completed card — green "Access until …" + Rewatch, or red
// "Expired on …" + Renew Course depending on `accessUntil`.
// ───────────────────────────────────────────────────────────────────
class _CompletedCard extends StatelessWidget {
  final CourseSummary course;

  const _CompletedCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM, y');
    final expired = course.isAccessExpired;
    // Tone bundle drives both the access-status colour and the bottom
    // CTA's neumorphism palette in one place.
    final palette = expired
        ? (
            text: course.accessUntil == null
                ? 'Access expired'
                : 'Expired on ${df.format(course.accessUntil!)}',
            color: AppColors.error,
            label: 'Renew Course',
            buttonTone: CustomActionButtonTone.error,
          )
        : (
            text: course.accessUntil == null
                ? 'Lifetime access'
                : 'Access until ${df.format(course.accessUntil!)}',
            color: AppColors.success,
            label: 'Rewatch',
            buttonTone: CustomActionButtonTone.success,
          );

    return _CourseCardShell(
      course: course,
      middle: Text(
        palette.text,
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: palette.color,
          fontSize: Screen.getFontSize(13),
          fontStyle: FontStyle.italic,
        ),
      ),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomActionButton(
            name: palette.label,
            isFormFilled: true,
            tone: palette.buttonTone,
            onTap: (_, __, ___) {
              if (expired) {
                // Renewal goes through course detail → Razorpay flow.
                context.push(
                  '${AppRoutes.courseDetail}?courseId=${course.courseId}',
                );
                return;
              }
              // Rewatch — reset progress server-side then locally so the
              // card slides back to In Progress with a 0% progress bar.
              // No purchasedId means the GET response didn't include one
              // (older endpoint); fall back to navigating into the course.
              final pid = course.purchasedId;
              if (pid == null) {
                context.push(
                  '${AppRoutes.courseDetail}?courseId=${course.courseId}',
                );
                return;
              }
              context.read<MyCoursesCubit>().rewatch(pid);
            },
          ),
          // Certificate action, secondary to the main CTA. Only rendered
          // when the educator issues one for this course — without the
          // flag the download endpoint can only 404, so there is nothing
          // worth offering. Shown for expired access too: the learner
          // finished the course, and that doesn't lapse with the
          // access window.
          if (course.hasCertificate) ...[
            SizedBox(height: Screen.getVerticalSize(10)),
            _CertificateButton(course: course),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Secondary "Download Certificate" pill under a completed course's
// main CTA. Holds its own busy flag rather than routing through
// MyCoursesCubit — a slow download (the API's first call after a
// restart spins up Chromium and can take a few seconds) then spins on
// this one card and leaves the rest of the list usable.
// ───────────────────────────────────────────────────────────────────
class _CertificateButton extends StatefulWidget {
  final CourseSummary course;

  const _CertificateButton({required this.course});

  @override
  State<_CertificateButton> createState() => _CertificateButtonState();
}

class _CertificateButtonState extends State<_CertificateButton> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    await openCertificate(
      context,
      courseId: widget.course.courseId,
      courseName: widget.course.courseTitle,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: Screen.getVerticalSize(46),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: _busy ? null : _download,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(
                    width: Screen.getSize(16),
                    height: Screen.getSize(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: Screen.getSize(18),
                    color: AppColors.primary,
                  ),
                SizedBox(width: Screen.getHorizontalSize(8)),
                Text(
                  _busy ? 'Preparing certificate…' : 'Download Certificate',
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.primary,
                    fontSize: Screen.getFontSize(14),
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

// ───────────────────────────────────────────────────────────────────
// Rendered when the source list has courses but the current search
// query matches none of them. Distinguishes from the "no purchases"
// state so the user knows it's the query, not the data.
// ───────────────────────────────────────────────────────────────────
class _NoSearchResults extends StatelessWidget {
  final String query;

  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              'No courses match "$query"',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Shared: empty / error state.
// ───────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? iconColor;

  const _EmptyState({
    required this.icon,
    required this.message,
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
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
