import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/transaction/domain/enums/transaction_filter.dart';
import 'package:nexora/features/transaction/presentation/widgets/filter_pill.dart';
import 'package:flutter/material.dart';

/// Date pill — opens the time-filter menu via [showMenu] anchored to
/// the pill's own bounds.
///
/// Uses [showMenu] instead of [PopupMenuButton] so the splash stays
/// clipped to [FilterPill]'s rounded shape (PopupMenuButton's internal
/// InkWell paints a rectangular ripple over the rounded pill).
class DatePill extends StatelessWidget {
  final TransactionTimeFilter value;
  final ValueChanged<TransactionTimeFilter> onChanged;

  const DatePill({super.key, required this.value, required this.onChanged});

  /// Popup menu items. `none` is included as the first option so the
  /// user can clear an active filter; it renders as "All time" via
  /// [TransactionTimeFilter.popupLabel].
  static const List<TransactionTimeFilter> _options = [
    TransactionTimeFilter.none,
    TransactionTimeFilter.lastWeek,
    TransactionTimeFilter.thisMonth,
    TransactionTimeFilter.lastMonth,
  ];

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 4,
      overlayBox.size.width - origin.dx - box.size.width,
      0,
    );
    final picked = await showMenu<TransactionTimeFilter>(
      context: context,
      position: position,
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: const RoundedRectangleBorder(borderRadius: AppSizes.borderRadiusL),
      items: [
        for (final f in _options)
          PopupMenuItem<TransactionTimeFilter>(
            value: f,
            // The default 16/8 padding clips the larger item we want.
            padding: EdgeInsets.zero,
            child: _DatePopupItem(label: f.popupLabel, selected: f == value),
          ),
      ],
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = value != TransactionTimeFilter.none;
    return FilterPill(
      label: value.label,
      selected: selected,
      onTap: () => _openMenu(context),
      trailing: const Icon(Icons.keyboard_arrow_down_rounded),
    );
  }
}

/// Single row inside the date popup — primary-coloured label + check
/// when selected, muted-grey label otherwise. Padding tuned to match
/// the spec's generous spacing.
class _DatePopupItem extends StatelessWidget {
  final String label;
  final bool selected;

  const _DatePopupItem({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? AppColors.primary : AppColors.mutedTextPrimary;
    return Padding(
      padding: Screen.getPadding(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: Screen.getFontSize(16),
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, size: 22, color: AppColors.primary),
        ],
      ),
    );
  }
}
