import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Rounded sheet chrome shared by every Store bottom sheet.
Future<T?> showStoreSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTypography.h6Bold)),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: builder(sheetContext)),
          ],
        ),
      ),
    ),
  );
}

Future<StoreSort?> showStoreSortSheet(BuildContext context, StoreSort current) {
  return showStoreSheet<StoreSort>(
    context,
    title: 'Sort by',
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
          for (final sort in StoreSort.values)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              onTap: () => Navigator.of(sheetContext).pop(sort),
              title: Text(
                sort.label,
                style: sort == current
                    ? AppTypography.bodyTextLargeBold.copyWith(
                        color: AppColors.primary,
                      )
                    : AppTypography.bodyTextLargeMedium,
              ),
              trailing: sort == current
                  ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: AppColors.grey300,
                    ),
            ),
        ],
      ),
    ),
  );
}

/// A price filter: `(min, max)`, either side open. Returned through
/// [StorePriceFilterResult] so "cleared" and "dismissed" differ.
class StorePriceFilterResult {
  final double? min;
  final double? max;

  const StorePriceFilterResult(this.min, this.max);
}

Future<StorePriceFilterResult?> showStorePriceSheet(
  BuildContext context, {
  double? min,
  double? max,
}) {
  return showStoreSheet<StorePriceFilterResult>(
    context,
    title: 'Price',
    builder: (_) => _PriceSheet(min: min, max: max),
  );
}

class _PriceSheet extends StatefulWidget {
  final double? min;
  final double? max;

  const _PriceSheet({this.min, this.max});

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  static const _presets = <(String, double?, double?)>[
    ('Under ₹250', null, 250),
    ('₹250 to ₹500', 250, 500),
    ('₹500 to ₹1,000', 500, 1000),
    ('₹1,000 to ₹2,500', 1000, 2500),
    ('Over ₹2,500', 2500, null),
  ];

  late final _minCtrl = TextEditingController(text: _fmt(widget.min));
  late final _maxCtrl = TextEditingController(text: _fmt(widget.max));
  String? _error;

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final min = double.tryParse(_minCtrl.text.trim());
    final max = double.tryParse(_maxCtrl.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _error = 'Minimum is more than maximum.');
      return;
    }
    Navigator.of(context).pop(StorePriceFilterResult(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final min = double.tryParse(_minCtrl.text.trim());
    final max = double.tryParse(_maxCtrl.text.trim());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, lo, hi) in _presets)
                ChoiceChip(
                  label: Text(label),
                  selected: min == lo && max == hi,
                  showCheckmark: false,
                  labelStyle: AppTypography.bodyTextSmallSemiBold.copyWith(
                    color: min == lo && max == hi
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                  selectedColor: AppColors.primaryFill,
                  backgroundColor: AppColors.grey100,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (_) => setState(() {
                    _minCtrl.text = _fmt(lo);
                    _maxCtrl.text = _fmt(hi);
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _field(_minCtrl, 'Min ₹')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('to', style: AppTypography.bodyTextMedium),
              ),
              Expanded(child: _field(_maxCtrl, 'Max ₹')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            StoreIssueText(message: _error!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StoreOutlinedButton(
                  label: 'Clear',
                  height: 48,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const StorePriceFilterResult(null, null)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StorePrimaryButton(
                  label: 'Apply',
                  height: 48,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    onChanged: (_) => setState(() => _error = null),
    style: AppTypography.bodyTextSemiBold,
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.grey100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

/// Yes / no confirmation in the Store's style.
Future<bool> showStoreConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      title: Text(title, style: AppTypography.h6Bold),
      content: Text(
        message,
        style: AppTypography.bodyTextMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Not now',
            style: AppTypography.buttonMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: AppTypography.buttonMedium.copyWith(
              color: destructive ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
