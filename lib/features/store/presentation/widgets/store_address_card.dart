import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';

/// Name, type, lines and phone of a saved address. Shared by the address
/// book and checkout.
class StoreAddressSummary extends StatelessWidget {
  final StoreAddress address;
  final bool showDefault;

  const StoreAddressSummary({
    super.key,
    required this.address,
    this.showDefault = true,
  });

  static IconData iconFor(StoreAddressType type) => switch (type) {
    StoreAddressType.home => Icons.home_rounded,
    StoreAddressType.work => Icons.apartment_rounded,
    StoreAddressType.other => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(a.fullName, style: AppTypography.bodyTextLargeBold),
            _Tag(
              label: a.type.label,
              icon: iconFor(a.type),
              color: AppColors.primary,
            ),
            if (showDefault && a.isDefault)
              const _Tag(label: 'Default', color: AppColors.success),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          a.streetLine,
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        Text(
          a.cityLine,
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.phone_outlined, size: 14, color: AppColors.grey400),
            const SizedBox(width: 5),
            Text(a.phone, style: AppTypography.bodyTextSmallSemiBold),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _Tag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
