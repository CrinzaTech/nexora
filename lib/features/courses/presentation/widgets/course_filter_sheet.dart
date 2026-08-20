import 'dart:ui';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_outlined_action_button.dart';
import 'package:nexora/core/widgets/gradient_border.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/presentation/bloc/course_filters_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Selection state returned by [CourseFilterSheet] when the user taps
/// "Apply Filters". A `null` ID means "no preference" / "all" — call sites
/// should treat absent fields as no-op rather than as a default.
class CourseFilters {
  /// Selected category ID — `null` means "All Categories".
  final int? categoryId;

  /// Selected category display name for UI convenience.
  final String categoryName;

  /// Selected course-type ID — `null` means "All".
  final int? typeId;

  /// Selected course-type display name for UI convenience.
  final String typeName;

  final String? level;
  final String? sortBy;

  const CourseFilters({
    this.categoryId,
    this.categoryName = 'All Categories',
    this.typeId,
    this.typeName = 'All',
    this.level,
    this.sortBy,
  });

  CourseFilters copyWith({
    Object? categoryId = _sentinel,
    String? categoryName,
    Object? typeId = _sentinel,
    String? typeName,
    Object? level = _sentinel,
    Object? sortBy = _sentinel,
  }) {
    return CourseFilters(
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as int?,
      categoryName: categoryName ?? this.categoryName,
      typeId: identical(typeId, _sentinel) ? this.typeId : typeId as int?,
      typeName: typeName ?? this.typeName,
      level: identical(level, _sentinel) ? this.level : level as String?,
      sortBy: identical(sortBy, _sentinel) ? this.sortBy : sortBy as String?,
    );
  }

  /// Sentinel that lets `copyWith` distinguish "field omitted" from
  /// "explicitly set to null" — needed because nullable ID fields can
  /// legitimately be cleared.
  static const Object _sentinel = Object();
}

/// Bottom sheet that lets the user pick category / type / level / sort
/// for the course list. Categories and course types are fetched from
/// the API via [CourseFiltersCubit]; level and sort remain static.
///
/// Use [show] to display it. Returns a [CourseFilters] when the user
/// taps "Apply Filters", or `null` if they dismiss the sheet.
class CourseFilterSheet extends StatefulWidget {
  final CourseFilters initial;

  const CourseFilterSheet({super.key, this.initial = const CourseFilters()});

  static Future<CourseFilters?> show(
    BuildContext context, {
    CourseFilters initial = const CourseFilters(),
  }) {
    return showModalBottomSheet<CourseFilters>(
      context: context,
      isScrollControlled: true,
      // Transparent so the sheet's own rounded container defines the
      // visible shape — modal default ships with a square top edge.
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => sl<CourseFiltersCubit>()..loadCategories(),
        child: CourseFilterSheet(initial: initial),
      ),
    );
  }

  @override
  State<CourseFilterSheet> createState() => _CourseFilterSheetState();
}

class _CourseFilterSheetState extends State<CourseFilterSheet> {
  // ───────────── Static option lists (no API for these yet) ───────────
  // static const List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  // static const List<String> _sortOptions = [
  //   'Popularity',
  //   'Trending',
  //   'Newest',
  //   'Top Rated',
  // ];

  late CourseFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  void _clearAll() {
    setState(() => _draft = const CourseFilters());
  }

  void _apply() {
    Navigator.of(context).pop(_draft);
  }

  // Shared with the navbar glass spec — same colour tokens.
  static const _borderLow = Color(0x1F6C63FF); // #6C63FF @ 12%
  static const _borderMid = Color(0x666C63FF); // #6C63FF @ 40%
  // Pale lavender lip on a light sheet; on a dark sheet the same trick
  // needs the elevated surface tone instead of a near-white.
  static Color get _innerShadowColor =>
      AppColors.isDark ? AppColors.grey100 : const Color(0xFFF1F1FF);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(AppSizes.radiusXXL),
      topRight: Radius.circular(AppSizes.radiusXXL),
    );

    final sheetContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: Screen.getVerticalSize(8)),
        Container(
          width: Screen.getHorizontalSize(40),
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.grey300.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Flexible(
          child: BlocBuilder<CourseFiltersCubit, CourseFiltersState>(
            builder: (context, state) {
              return state.maybeWhen(
                loading: () => _buildLoading(),
                loaded: (data) => _buildFilterContent(data),
                error: (message) => _buildError(context, message),
                orElse: () => _buildLoading(),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: Screen.getHorizontalSize(20),
            right: Screen.getHorizontalSize(20),
            top: Screen.getVerticalSize(12),
            bottom:
                MediaQuery.of(context).padding.bottom +
                Screen.getVerticalSize(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: CustomOutlinedActionButton(
                  isFormFilled: true,
                  name: 'Clear All',
                  buttonHeight: Screen.getVerticalSize(50),
                  onTap: (_, __, ___) => _clearAll(),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: CustomActionButton(
                  isFormFilled: true,
                  name: 'Apply Filters',
                  buttonHeight: Screen.getVerticalSize(50),
                  onTap: (_, __, ___) => _apply(),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // Outer drop shadow — must sit outside ClipRRect so the shadow
      // bleeds past the rounded top corners.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 33, sigmaY: 33),
            child: Stack(
              children: [
                // Glass surface — translucent white + gradient border.
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.55),
                    borderRadius: radius,
                    border: GradientBorder(
                      gradient: const LinearGradient(
                        colors: [_borderLow, _borderMid, _borderLow],
                      ),
                      width: 1,
                    ),
                  ),
                  child: sheetContent,
                ),

                // Inner shadow — same spec as the navbar.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: InnerShadowPainter(
                        color: _innerShadowColor,
                        blurRadius: 10,
                        offset: const Offset(-2, 3),
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Loading state
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return SizedBox(
      height: Screen.getVerticalSize(300),
      child: Center(
        child: SpinKitThreeBounce(
          color: AppColors.primary,
          size: Screen.getSize(24),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Error state
  // ─────────────────────────────────────────────────────────────
  Widget _buildError(BuildContext context, String message) {
    return SizedBox(
      height: Screen.getVerticalSize(300),
      child: Center(
        child: Padding(
          padding: Screen.getPadding(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              SizedBox(height: Screen.getVerticalSize(12)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(16)),
              TextButton(
                onPressed: () =>
                    context.read<CourseFiltersCubit>().loadCategories(),
                child: Text(
                  'Retry',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Loaded state — full filter content
  // ─────────────────────────────────────────────────────────────
  Widget _buildFilterContent(CourseFilterData data) {
    // Build the category chip options: "All Categories" + API categories
    final categoryOptions = <_ChipOption>[
      const _ChipOption(id: null, label: 'All Categories'),
      ...data.categories.map(
        (c) => _ChipOption(id: c.categoryId, label: c.categoryName),
      ),
    ];

    // Build the course type chip options from API data.
    // Skip the "All" entry (typeId: 0) — no selection means "All" implicitly,
    // so we only show the concrete options (Free, Paid, etc.).
    final typeOptions = data.courseTypes
        .where((t) => t.typeId != 0)
        .map((t) => _ChipOption(id: t.typeId, label: _toTitleCase(t.typeName)))
        .toList();

    return SingleChildScrollView(
      padding: Screen.getPadding(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filter By',
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(20)),

          // ── Category section (dynamic) ──
          _FilterSectionDynamic(
            label: 'CATEGORY',
            options: categoryOptions,
            selectedId: _draft.categoryId,
            onSelected: (option) => setState(
              () => _draft = _draft.copyWith(
                categoryId: option.id,
                categoryName: option.label,
              ),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(20)),

          // ── Course Type section (dynamic) ──
          // Single-select: tapping a chip selects it; tapping it again clears
          // the filter. No chip selected = "All" (no type filter applied).
          _FilterSectionDynamic(
            label: 'COURSE TYPE',
            options: typeOptions,
            selectedId: _draft.typeId,
            onSelected: (option) {
              setState(() {
                if (option.id == _draft.typeId) {
                  // Deselect — back to "All"
                  _draft = CourseFilters(
                    categoryId: _draft.categoryId,
                    categoryName: _draft.categoryName,
                    level: _draft.level,
                    sortBy: _draft.sortBy,
                  );
                } else {
                  _draft = _draft.copyWith(
                    typeId: option.id,
                    typeName: option.label,
                  );
                }
              });
            },
          ),
          SizedBox(height: Screen.getVerticalSize(20)),

          // ── Level section (static) ──
          // _FilterSection(
          //   label: 'LEVEL',
          //   options: _levels,
          //   selected: _draft.level,
          //   onSelected: (v) => setState(
          //     () => _draft = _draft.copyWith(
          //       level: _draft.level == v ? null : v,
          //     ),
          //   ),
          // ),
          // SizedBox(height: Screen.getVerticalSize(20)),

          // ── Sort By section (static) ──
          // _FilterSection(
          //   label: 'SORT BY',
          //   options: _sortOptions,
          //   selected: _draft.sortBy,
          //   onSelected: (v) => setState(
          //     () => _draft = _draft.copyWith(
          //       sortBy: _draft.sortBy == v ? null : v,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Chip option model (for dynamic ID-based sections)
// ─────────────────────────────────────────────────────────────

class _ChipOption {
  final int? id;
  final String label;

  const _ChipOption({required this.id, required this.label});
}

// ─────────────────────────────────────────────────────────────
// Dynamic section (ID-based selection — categories / course types)
// ─────────────────────────────────────────────────────────────

class _FilterSectionDynamic extends StatelessWidget {
  final String label;
  final List<_ChipOption> options;
  final int? selectedId;
  final ValueChanged<_ChipOption> onSelected;

  const _FilterSectionDynamic({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.grey400,
            letterSpacing: 1.0,
            fontSize: Screen.getFontSize(12),
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(12)),
        Wrap(
          spacing: Screen.getHorizontalSize(10),
          runSpacing: Screen.getVerticalSize(10),
          children: options
              .map(
                (option) => _FilterChip(
                  label: option.label,
                  isSelected: option.id == selectedId,
                  onTap: () => onSelected(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Static section + chip primitives (unchanged from original)
// ─────────────────────────────────────────────────────────────

// class _FilterSection extends StatelessWidget {
//   final String label;
//   final List<String> options;
//   final String? selected;
//   final ValueChanged<String> onSelected;

//   const _FilterSection({
//     required this.label,
//     required this.options,
//     required this.selected,
//     required this.onSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: AppTypography.labelMedium.copyWith(
//             color: AppColors.grey400,
//             letterSpacing: 1.0,
//             fontSize: Screen.getFontSize(12),
//           ),
//         ),
//         SizedBox(height: Screen.getVerticalSize(12)),
//         Wrap(
//           spacing: Screen.getHorizontalSize(10),
//           runSpacing: Screen.getVerticalSize(10),
//           children: options
//               .map(
//                 (option) => _FilterChip(
//                   label: option,
//                   isSelected: option == selected,
//                   onTap: () => onSelected(option),
//                 ),
//               )
//               .toList(),
//         ),
//       ],
//     );
//   }
// }

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(50);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: Screen.getPadding(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.white,
            borderRadius: radius,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: Screen.getSize(16),
                  color: AppColors.alwaysWhite,
                ),
                SizedBox(width: Screen.getHorizontalSize(6)),
              ],
              Text(
                label,
                style: AppTypography.bodyTextSemiBold.copyWith(
                  fontSize: Screen.getFontSize(13),
                  color: isSelected ? AppColors.alwaysWhite : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(34);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: Screen.getSize(18),
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}
