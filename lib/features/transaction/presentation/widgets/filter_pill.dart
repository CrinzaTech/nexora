import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Shared pill chip used by both the Date popup and the status chips
/// on the Transaction History filter bar.
///
/// Matches the spec: rounded pill, 1.5px border (primary when
/// `selected`, muted grey otherwise), white surface, label in primary
/// when selected and muted-text otherwise.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;

  /// Tap handler. Pass `null` when an ancestor widget needs to own the
  /// gesture — otherwise the pill's inner [InkWell] swallows the tap
  /// and the parent never fires.
  final VoidCallback? onTap;

  /// Optional trailing icon — only the date pill uses it (chevron).
  final Widget? trailing;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary
        : AppColors.mutedTextPrimary.withValues(alpha: 0.35);
    final textColor = selected ? AppColors.primary : AppColors.mutedTextPrimary;

    final pill = Container(
      padding: Screen.getPadding(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodyTextMedium.copyWith(
              color: textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: Screen.getFontSize(14),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: Screen.getHorizontalSize(6)),
            IconTheme(
              data: IconThemeData(color: textColor, size: 18),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    // No own tap handler → render the pill purely visually so a parent
    // gesture detector can pick up the tap (e.g. when wrapped in a
    // PopupMenuButton-style container that owns the gesture).
    if (onTap == null) return pill;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: pill),
    );
  }
}
