import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/courses/presentation/bloc/search_courses_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/search_results_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dedicated search screen.
///
/// Pushed from the home search bar. Both [initialQuery] and [initialIsPaid]
/// can be supplied via route query params (`searchQuery`, `isPaid`) so that
/// callers can deep-link into a pre-filtered search — e.g. open the page
/// already showing only paid courses for "flutter".
class SearchPage extends StatefulWidget {
  final String? initialQuery;
  final bool? initialIsPaid;

  const SearchPage({super.key, this.initialQuery, this.initialIsPaid});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SearchCoursesCubit _cubit;
  late bool? _isPaid;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode();
    _isPaid = widget.initialIsPaid;
    _cubit = sl<SearchCoursesCubit>()..setIsPaid(_isPaid);
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    // If we were opened with a seeded query, fire it immediately rather
    // than waiting for the user to type.
    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      _cubit.search(seed, isPaid: _isPaid);
    } else {
      // Request focus automatically if there is no initial query
      _focusNode.requestFocus();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cubit.loadNextPage();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onTextChanged() {
    _cubit.search(_controller.text, isPaid: _isPaid);
  }



  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return BlocProvider<SearchCoursesCubit>.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          elevation: 0,
          titleSpacing: 0,
          // Slightly taller toolbar so the pill field has vertical
          // breathing room above and below — the default toolbarHeight
          // (56) crops the field against the AppBar's bottom edge.
          toolbarHeight: Screen.getVerticalSize(64),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: Screen.getSize(24)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          // Pad the right edge so the field doesn't run flush against
          // the AppBar's trailing edge.
          title: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              hintText: 'Search courses',
              onChanged: (_) {}, // handled by listener
              onClear: _controller.clear,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<SearchCoursesCubit, SearchCoursesState>(
                builder: (context, state) {
                  return state.maybeWhen(
                    idle: () => _IdleHint(),
                    orElse: () => SearchResultsPanel(scrollController: _scrollController),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: Screen.getSize(64), color: AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              'Find your next course',
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              'Search by course name.',
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
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

/// Convenience builder used by the router to construct the page from query
/// params. Lives here so the route logic stays declarative.
SearchPage searchPageFromQuery(Map<String, String> params) {
  final raw = params['isPaid']?.toLowerCase();
  final bool? isPaid = raw == null
      ? null
      : raw == 'true'
      ? true
      : raw == 'false'
      ? false
      : null;
  return SearchPage(initialQuery: params['searchQuery'], initialIsPaid: isPaid);
}
