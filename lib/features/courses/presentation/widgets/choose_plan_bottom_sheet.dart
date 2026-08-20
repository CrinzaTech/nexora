// ignore: unnecessary_import — flutter/material.dart re-exports ImageFilter
// in newer SDKs but the project's pinned channel doesn't, so keep this
// explicit dart:ui import to satisfy the BackdropFilter call below.
import 'dart:ui';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Choose Plan" tier-picker bottom sheet — opens before the enrolment
/// flow when the course has more than one buyable tier. The user picks
/// a tier (radio + price card), taps Proceed, and the caller routes
/// the selected `coursePricingId` into the existing pricing-v2 →
/// create-order-v2 chain.
///
/// Selection state is local to the sheet: a stateful host tracks the
/// currently-highlighted tier and the bottom CTA fires
/// [onProceed] with that tier's id when tapped. Closing the sheet
/// without proceeding is a clean cancel — the host does nothing.
class ChoosePlanBottomSheet extends StatefulWidget {
  final List<CoursePricingTier> tiers;
  final void Function(CoursePricingTier selected) onProceed;

  const ChoosePlanBottomSheet({
    super.key,
    required this.tiers,
    required this.onProceed,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CoursePricingTier> tiers,
    required void Function(CoursePricingTier selected) onProceed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChoosePlanBottomSheet(
        tiers: tiers,
        onProceed: onProceed,
      ),
    );
  }

  @override
  State<ChoosePlanBottomSheet> createState() => _ChoosePlanBottomSheetState();
}

class _ChoosePlanBottomSheetState extends State<ChoosePlanBottomSheet> {
  /// Index of the currently-selected tier. Defaults to the first tier
  /// so the sheet always opens with a valid selection — the CTA is
  /// enabled the moment the user can see prices.
  int _selected = 0;

  /// Index of the "Recommended" tier — purely visual. With no backend
  /// field for this yet, we badge the middle tier of a 3+ tier list
  /// (matches the design mock where the 6-month plan is recommended
  /// in a 3-plan layout). Returns `-1` to suppress the badge.
  int get _recommendedIndex {
    if (widget.tiers.length < 3) return -1;
    return widget.tiers.length ~/ 2;
  }

  void _onSelect(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
  }

  void _proceed() {
    Navigator.of(context).pop();
    widget.onProceed(widget.tiers[_selected]);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(AppSizes.radiusXXL),
      topRight: Radius.circular(AppSizes.radiusXXL),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // Figma spec: top edge picks up a 6 px white lip above the
      // sheet (drop shadow Y = -6, blur = 0, colour #FFFFFF @ 50%),
      // and the sheet body sits behind a 44 px backdrop blur tinted
      // with #E3E2FF @ 17 %. The outer Container carries the shadow;
      // the inner ClipRRect + BackdropFilter does the wash so the
      // blur clips to the rounded top corners.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.white.withValues(alpha: 0.50),
              blurRadius: 0,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE3E2FF).withValues(alpha: 0.17),
                borderRadius: radius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: Screen.getVerticalSize(10)),
                  Container(
                    width: Screen.getHorizontalSize(40),
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey300.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(8)),
                  _Header(onClose: () => Navigator.of(context).pop()),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          Screen.getPadding(horizontal: 18, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < widget.tiers.length; i++) ...[
                            _PlanCard(
                              tier: widget.tiers[i],
                              isSelected: _selected == i,
                              isRecommended: i == _recommendedIndex,
                              onTap: () => _onSelect(i),
                            ),
                            if (i != widget.tiers.length - 1)
                              SizedBox(height: Screen.getVerticalSize(14)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: Screen.getHorizontalSize(18),
                      right: Screen.getHorizontalSize(18),
                      top: Screen.getVerticalSize(8),
                      bottom: MediaQuery.of(context).padding.bottom +
                          Screen.getVerticalSize(16),
                    ),
                    child: CustomActionButton(
                      isFormFilled: true,
                      buttonHeight: Screen.getVerticalSize(54),
                      name: 'Proceed to Pay Securely',
                      onTap: (_, __, ___) => _proceed(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top row: "Choose Plan" title + circular outline close button.
class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Choose Plan',
              style: AppTypography.h4SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(36);
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            size: Screen.getSize(20),
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// One tier in the picker. Selected state inflates the card with a
/// purple border and reveals the feature list; unselected cards stay
/// compact (radio + title + price + discount).
class _PlanCard extends StatelessWidget {
  final CoursePricingTier tier;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _PlanCard({
    required this.tier,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  /// Plan title derived from the tier's duration metadata. Falls
  /// through to a custom-expiry date string when [customExpiryDate]
  /// is set. The `durationType` enum mapping is inferred from
  /// observed v2 responses (1 = Month, 2 = Day, 3 = Year) — flip
  /// here if the backend later documents otherwise.
  String _title() {
    final custom = tier.customExpiryDate;
    if (custom != null) {
      return 'Until ${DateFormat('d MMM y').format(custom)}';
    }
    final n = tier.durationOfCourse;
    String pluralise(String unit) => '$n $unit${n == 1 ? '' : 's'}';
    switch (tier.durationType) {
      case 1:
        return pluralise('Month');
      case 2:
        return pluralise('Day');
      case 3:
        return pluralise('Year');
      default:
        return '$n Units';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = tier.hasDiscount;
    // Figma's literal values (#FFFFFF @ 40 %, border #6C63FF, shadow
    // #6C63FF @ 32 %) render way too hot in Flutter on top of the
    // sheet's lavender backdrop — every layer compounds the purple
    // cast. Dialled the visual weight down while keeping the spec's
    // intent (selected tile = bordered + softly haloed):
    //   selected   → solid white fill, 1.2 px #6C63FF border,
    //                #6C63FF @ 10 % shadow (blur 9)
    //   unselected → solid white, no border, no shadow
    // Radio + features-list expansion carry the rest of the
    // selection cue, so the primary tint stays a subtle accent.
    final accent = AppColors.primary;
    final radius = BorderRadius.circular(AppSizes.radiusL);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: radius,
            border: isSelected
                ? Border.all(color: accent, width: 1.2)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.10),
                      blurRadius: 9,
                      offset: Offset.zero,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: Screen.getPadding(horizontal: 16, vertical: 16),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _Radio(selected: isSelected),
                      SizedBox(width: Screen.getHorizontalSize(12)),
                      Text(
                        _title(),
                        // Tile titles were sitting at h5 (~18 pt) which
                        // dwarfed the rest of the card; bodyTextLarge
                        // SemiBold (~14 pt) reads as a label, not a
                        // section header.
                        style: AppTypography.bodyTextLargeSemiBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Screen.getVerticalSize(10)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹ ${Utils.formatPrice(tier.calculatedFinalPrice > 0 ? tier.calculatedFinalPrice : tier.discountedPrice)}',
                        // Was h4 (~22 pt) — dropped to h6 (~16 pt) so
                        // it still stands out as the primary number
                        // without dominating the tile.
                        style: AppTypography.h6SemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasDiscount) ...[
                        SizedBox(width: Screen.getHorizontalSize(8)),
                        Text(
                          '₹ ${Utils.formatPrice(tier.originalPrice)}',
                          style: AppTypography.bodyTextMedium.copyWith(
                            color: AppColors.mutedTextPrimary,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.mutedTextPrimary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if ((tier.discountText ?? '').isNotEmpty)
                        Container(
                          padding: Screen.getPadding(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.discountBadgeBackground,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: Text(
                            tier.discountText!,
                            style: AppTypography.bodyTextSemiBold.copyWith(
                              color: AppColors.alwaysWhite,
                              fontSize: Screen.getFontSize(11),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Feature list — shown only on the selected card to
                  // mirror the design. Hardcoded today; swap to a
                  // backend-driven list once tiers ship benefits.
                  if (isSelected) ...[
                    SizedBox(height: Screen.getVerticalSize(14)),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.mutedTextPrimary.withValues(alpha: 0.18),
                    ),
                    SizedBox(height: Screen.getVerticalSize(12)),
                    const _Feature(text: 'Access to all modules'),
                    SizedBox(height: Screen.getVerticalSize(10)),
                    const _Feature(text: 'Certificate upon completion'),
                    SizedBox(height: Screen.getVerticalSize(10)),
                    const _Feature(text: 'Personal interaction with mentor'),
                  ],
                ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isRecommended)
          Positioned(
            right: Screen.getHorizontalSize(16),
            top: -Screen.getVerticalSize(12),
            child: Container(
              padding: Screen.getPadding(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
              ),
              child: Text(
                'Recommended',
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.alwaysWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: Screen.getFontSize(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;

  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(22);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.mutedTextPrimary,
          width: 2,
        ),
        color: selected ? AppColors.primary : Colors.transparent,
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: size * 0.45,
              height: size * 0.45,
              decoration: const BoxDecoration(
                color: AppColors.alwaysWhite,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;

  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.check_rounded,
          size: Screen.getSize(16),
          color: AppColors.textPrimary,
        ),
        SizedBox(width: Screen.getHorizontalSize(8)),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
