import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// The checkout breakdown, line by line exactly as the server sent it
/// (BUNDLE_API.md §5). Nothing here adds anything up.
class BundlePricingBreakdown extends StatelessWidget {
  final BundlePricing pricing;

  const BundlePricingBreakdown({super.key, required this.pricing});

  @override
  Widget build(BuildContext context) {
    final p = pricing;
    final gstLabel = 'GST (${_percent(p.gstPercentage)})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreBillRow(
          label: 'Actual price',
          value: StoreFormat.money(p.actualPrice),
        ),
        if (p.bundleDiscount > 0)
          StoreBillRow(
            label: 'Bundle discount',
            value: '−${StoreFormat.money(p.bundleDiscount)}',
            valueColor: AppColors.success,
          ),
        if (p.ownedReduction > 0)
          StoreBillRow(
            label: 'Courses you already own (${p.ownedCourseCount})',
            value: '−${StoreFormat.money(p.ownedReduction)}',
            valueColor: AppColors.success,
          ),
        StoreBillRow(label: 'Subtotal', value: StoreFormat.money(p.subtotal)),
        // Inclusive GST is already inside the subtotal: an info line,
        // added to nothing.
        if (p.gstAmount > 0)
          p.isGstInclusive
              ? StoreBillRow(
                  label: 'Includes $gstLabel',
                  value: StoreFormat.money(p.gstAmount),
                  valueColor: AppColors.mutedTextPrimary,
                )
              : StoreBillRow(
                  label: gstLabel,
                  value: StoreFormat.money(p.gstAmount),
                ),
        if (p.internetCharges > 0)
          StoreBillRow(
            label:
                'Internet handling (${_percent(p.internetChargesPercentage)})',
            value: StoreFormat.money(p.internetCharges),
          ),
        if (p.platformFees > 0)
          StoreBillRow(
            label: 'Platform fee (${_percent(p.platformFeesPercentage)})',
            value: StoreFormat.money(p.platformFees),
          ),
        const StoreDashedDivider(),
        StoreBillRow(
          label: 'Total',
          value: StoreFormat.money(p.totalPayable),
          emphasis: true,
        ),
        if (p.isGstInclusive && p.gstAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Prices include GST.',
              style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ),
      ],
    );
  }

  /// "18%", "2.5%" — no trailing ".0".
  static String _percent(double value) {
    final text = value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$text%';
  }
}
