import 'dart:math';
import 'dart:ui';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';

import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/scrolling_title.dart';
import 'package:nexora/core/widgets/swipe_to_pay_button.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/bloc/course_pricing_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Order-summary bottom sheet that confirms enrolment details before
/// launching Razorpay.
///
/// Triggered from the "Buy Now" button on the course detail page after
/// the v2 `course/pricing-v2?CourseId=&PriceId=` request resolves. The
/// host [CoursePricingCubit] (passed via [show]) drives a single
/// loaded/error state — the v1 inline coupon-apply flow is gone (the
/// v2 endpoint doesn't accept a coupon code), so the sheet shows the
/// breakdown the backend returned for the chosen tier verbatim.
class EnrollmentBottomSheet extends StatefulWidget {
  final int courseId;

  /// Fires when the user taps "Proceed to Pay Securely". Receives the
  /// currently-loaded [CoursePricing] — the host reads
  /// `pricing.coursePriceId` off it to call `create-order-v2`.
  final void Function(CoursePricing pricing) onProceed;

  const EnrollmentBottomSheet({
    super.key,
    required this.courseId,
    required this.onProceed,
  });

  static Future<void> show(
    BuildContext context, {
    required int courseId,
    required CoursePricingCubit cubit,
    required void Function(CoursePricing pricing) onProceed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      // Transparent so the sheet's own rounded container defines the
      // visible shape — modal default ships with a square top edge.
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return BlocProvider.value(
          value: cubit,
          child: EnrollmentBottomSheet(
            courseId: courseId,
            onProceed: onProceed,
          ),
        );
      },
    );
  }

  @override
  State<EnrollmentBottomSheet> createState() => _EnrollmentBottomSheetState();
}

class _EnrollmentBottomSheetState extends State<EnrollmentBottomSheet> {
  /// The last successfully-loaded pricing — kept so we can continue
  /// showing the full sheet while a coupon-apply request is in-flight
  /// (instead of replacing the whole sheet with a spinner).
  CoursePricing? _lastKnownPricing;

  /// The coupon amount we've already shown the celebration overlay for —
  /// guards against re-showing it on unrelated rebuilds/re-emits of the
  /// same loaded state.
  double? _celebratedCouponAmount;

  void _proceed(CoursePricing pricing) {
    Navigator.of(context).pop();
    widget.onProceed(pricing);
  }

  void _maybeCelebrateCoupon(CoursePricing pricing) {
    if (!pricing.isCouponApplied ||
        pricing.couponOfferAmount == _celebratedCouponAmount) {
      return;
    }
    _celebratedCouponAmount = pricing.couponOfferAmount;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CouponCelebrationOverlay(
        savedAmount: pricing.couponOfferAmount,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    // Push the sheet above the keyboard when it opens.
    // viewInsets.bottom is non-zero only while the keyboard is visible,
    // so this has no effect when the keyboard is closed.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    const radius = BorderRadius.only(
      topLeft: Radius.circular(AppSizes.radiusXXL),
      topRight: Radius.circular(AppSizes.radiusXXL),
    );

    // The sheet takes full width on all devices including tablets and phones
    // to match the requested design layout.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: double.infinity,
          ),
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
                  child: BlocConsumer<CoursePricingCubit, CoursePricingState>(
                    listener: (context, state) {
                      state.maybeWhen(
                        loaded: (p) {
                          // Only celebrate coupon re-fetches, not the
                          // sheet's very first pricing load.
                          if (_lastKnownPricing != null) {
                            _maybeCelebrateCoupon(p);
                          }
                        },
                        orElse: () {},
                      );
                    },
                    builder: (context, state) {
                      final pricing = state.maybeWhen(
                        loaded: (p) => p,
                        orElse: () => null,
                      );

                      // Update the cache directly in the builder so it correctly captures
                      // the initial loaded state (the listener wouldn't fire for the initial state).
                      if (pricing != null) {
                        _lastKnownPricing = pricing;
                      }

                      // Derive flags that the _CouponSection and content need.
                      final isApplyingCoupon = state.maybeWhen(
                        loading: () => _lastKnownPricing != null,
                        orElse: () => false,
                      );
                      final couponError = state.maybeWhen(
                        error: (m) => _lastKnownPricing != null ? m : null,
                        orElse: () => null,
                      );

                      // Use last-known pricing to keep the sheet alive during
                      // coupon-apply loading or after a coupon-apply error.
                      final displayPricing = pricing ?? _lastKnownPricing;

                      if (displayPricing == null) {
                        // True initial load — no pricing known yet.
                        return _LoadingShim(
                          isError: state.maybeWhen(
                            error: (_) => true,
                            orElse: () => false,
                          ),
                          message: state.maybeWhen(
                            error: (m) => m,
                            orElse: () => null,
                          ),
                        );
                      }

                      return _SheetContent(
                        pricing: displayPricing,
                        isApplyingCoupon: isApplyingCoupon,
                        couponError: couponError,
                        onProceed: () => _proceed(displayPricing),
                        onApplyCoupon: (code) {
                          context.read<CoursePricingCubit>().load(
                            courseId: displayPricing.courseId,
                            priceId: displayPricing.coursePriceId,
                            couponCode: code,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loading + error shim — shown while the cubit hasn't produced
// a CoursePricing yet (initial / loading / error states).
// ─────────────────────────────────────────────────────────────
class _LoadingShim extends StatelessWidget {
  final bool isError;
  final String? message;

  const _LoadingShim({required this.isError, this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isError) ...[
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not fetch pricing',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Calculating your price…',
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Main content stack — title, course card, summary, CTA.
// ─────────────────────────────────────────────────────────────
class _SheetContent extends StatelessWidget {
  final CoursePricing pricing;
  final VoidCallback onProceed;
  final ValueChanged<String> onApplyCoupon;
  final bool isApplyingCoupon;
  final String? couponError;

  const _SheetContent({
    required this.pricing,
    required this.onProceed,
    required this.onApplyCoupon,
    required this.isApplyingCoupon,
    this.couponError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Flexible(
          child: SingleChildScrollView(
            padding: Screen.getPadding(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Complete Enrolment',
                        style: AppTypography.h5SemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: ResponsiveHelper.of(
                            context,
                          ).cappedFontSize(24),
                        ),
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
                SizedBox(height: Screen.getVerticalSize(20)),

                _CourseCard(pricing: pricing),
                SizedBox(height: Screen.getVerticalSize(14)),

                _OrderSummaryCard(pricing: pricing),
                SizedBox(height: Screen.getVerticalSize(20)),

                _CouponSection(
                  pricing: pricing,
                  isLoading: isApplyingCoupon,
                  overrideError: couponError,
                  onApply: onApplyCoupon,
                ),

                SizedBox(height: Screen.getVerticalSize(18)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: Screen.getSize(16),
                      color: AppColors.mutedTextPrimary,
                    ),
                    SizedBox(width: Screen.getHorizontalSize(8)),
                    Flexible(
                      child: Text(
                        '100% Secure & Encrypted Payment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                          fontSize: ResponsiveHelper.of(
                            context,
                          ).cappedFontSize(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: Screen.getHorizontalSize(20),
            right: Screen.getHorizontalSize(20),
            top: Screen.getVerticalSize(8),
            bottom:
                MediaQuery.of(context).padding.bottom +
                Screen.getVerticalSize(16),
          ),
          child: SwipeToPayButton(
            // Nothing to pay (free course, or a coupon that zeroed the
            // total) — "Proceed to Pay Securely" would be misleading.
            text: pricing.totalPayable <= 0
                ? 'Unlock Course'
                : 'Proceed to Pay Securely',
            onSwipeComplete: onProceed,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Course card — thumbnail + title pill at the top of the sheet.
// ─────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CoursePricing pricing;

  const _CourseCard({required this.pricing});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final imageWidth = rh.isLargeScreen
        ? Screen.getSize(140)
        : Screen.getSize(60);
    final imageHeight = rh.isLargeScreen
        ? Screen.getSize(90)
        : Screen.getSize(60);

    return Container(
      padding: Screen.getPadding(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            child: CustomNetworkImage(
              url: pricing.courseImageUrl,
              width: imageWidth,
              height: imageHeight,
              errorWidget: Container(
                width: imageWidth,
                height: imageHeight,
                color: AppColors.grey100,
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.grey300,
                ),
              ),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(14)),
          Expanded(
            child: ScrollingTitle(
              text: pricing.courseTitle,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Order summary — full backend price breakdown.
// ─────────────────────────────────────────────────────────────
class _OrderSummaryCard extends StatelessWidget {
  final CoursePricing pricing;

  const _OrderSummaryCard({required this.pricing});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = pricing.discountedPrice > 0;
    final hasInternetCharges = pricing.internetChargesAmount > 0;
    final hasTax = pricing.taxAmount > 0;
    final hasPlatformFee = pricing.platformFees > 0;
    final hasCoupon = pricing.isCouponApplied;
    // No discount: `totalGrantedAmount` is the actual course price the
    // backend grants. When a discount applies, "Course Price" shows the
    // pre-discount MRP (`originalPrice`, struck through) while the
    // "Discounted" row below shows `totalGrantedAmount` as the real price.
    final coursePrice = hasDiscount
        ? pricing.originalPrice
        : pricing.totalGrantedAmount;

    return Container(
      padding: Screen.getPadding(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER SUMMARY',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.grey400,
              letterSpacing: 1.0,
              fontSize: Screen.getFontSize(12),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(14)),

          _SummaryRow(
            label: 'Course Price',
            value: '₹ ${Utils.formatPrice(coursePrice)}',
            valueStyle: hasDiscount
                ? AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.mutedTextPrimary,
                  )
                : AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.successDark,
                  ),
          ),
          if (hasDiscount) ...[
            SizedBox(height: Screen.getVerticalSize(12)),
            _SummaryRow(
              label: pricing.totalDiscountGranted.isNotEmpty
                  ? 'Discounted (${pricing.totalDiscountGranted})'
                  : 'Discounted',
              value: '₹ ${Utils.formatPrice(pricing.totalGrantedAmount)}',
              valueStyle: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.discountBadgeBackground,
              ),
            ),
          ],

          if (hasCoupon) ...[
            SizedBox(height: Screen.getVerticalSize(12)),
            _SummaryRow(
              label: pricing.couponDiscountPercentageValue > 0
                  ? 'Coupon (${Utils.formatPrice(pricing.couponDiscountPercentageValue)}%)'
                  : 'Coupon',
              value: '− ₹ ${Utils.formatPrice(pricing.couponOfferAmount)}',
              valueStyle: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.successDark,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(12)),
            Container(
              padding: Screen.getPadding(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: _SummaryRow(
                label: 'After Discount',
                value:
                    '₹ ${Utils.formatPrice(pricing.couponDiscountedRemainAmount)}',
                labelStyle: AppTypography.bodyTextSmallMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                valueStyle: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],

          if (hasTax) ...[
            SizedBox(height: Screen.getVerticalSize(12)),
            _SummaryRow(
              label: pricing.isGstPaidByStudent
                  ? 'GST (${Utils.formatPrice(pricing.taxAppliedPercentage > 0 ? pricing.taxAppliedPercentage : 18.0)}%) Excl.'
                  : 'GST (${Utils.formatPrice(pricing.taxAppliedPercentage > 0 ? pricing.taxAppliedPercentage : 18.0)}%) Incl.',
              value: '₹ ${Utils.formatPrice(pricing.taxAmount)}',
            ),
          ],
          if (hasInternetCharges) ...[
            SizedBox(height: Screen.getVerticalSize(12)),
            _SummaryRow(
              label: 'Convenience Fee',
              value: '₹ ${Utils.formatPrice(pricing.internetChargesAmount)}',
            ),
          ],
          if (hasPlatformFee) ...[
            SizedBox(height: Screen.getVerticalSize(12)),
            _SummaryRow(
              label: 'Platform Fee',
              value: '₹ ${Utils.formatPrice(pricing.platformFees)}',
            ),
          ],

          SizedBox(height: Screen.getVerticalSize(14)),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.mutedTextPrimary.withValues(alpha: 0.18),
          ),
          SizedBox(height: Screen.getVerticalSize(14)),
          _SummaryRow(
            label: 'Total Payable',
            labelStyle: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
            value: '₹ ${Utils.formatPrice(pricing.totalPayable)}',
            valueStyle: AppTypography.bodyTextXtraLargeSemiBold.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                labelStyle ??
                AppTypography.bodyTextSmallMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        Text(
          value,
          style:
              valueStyle ??
              AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Close button — circular outlined X in the top-right.
// ─────────────────────────────────────────────────────────────
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(36);
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
            color: AppColors.white.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.5),
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

// ─────────────────────────────────────────────────────────────
// Coupon Section — text field to apply coupon code.
// Loading is shown inline on the Apply button only.
// ─────────────────────────────────────────────────────────────
class _CouponSection extends StatefulWidget {
  final CoursePricing pricing;
  final ValueChanged<String> onApply;

  /// True while the cubit is re-fetching pricing for coupon apply.
  final bool isLoading;

  /// Non-null when the coupon apply request returned an error but we
  /// have a last-known pricing to keep displaying.
  final String? overrideError;

  const _CouponSection({
    required this.pricing,
    required this.onApply,
    required this.isLoading,
    this.overrideError,
  });

  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill the coupon field if a coupon is already applied.
    if (widget.pricing.isCouponApplied &&
        widget.pricing.couponValidityMessage != null) {
      // We don't have the raw code from the pricing model, but if a
      // coupon is applied the field can stay blank — the summary card
      // will show the applied discount row.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleApply() {
    final code = _controller.text.trim();
    if (code.isNotEmpty && !widget.isLoading) {
      // Step 1: Close the keyboard first so the sheet settles to its
      // natural (no-keyboard) height cleanly before the request fires.
      FocusScope.of(context).unfocus();

      // Step 2: Wait for the keyboard slide-down animation to finish
      // (~300 ms), then fire the cubit request. This way the sheet is
      // already at its resting position when the loading state kicks in —
      // it will never drop mid-request. No setState is used; the cubit
      // drives all loading/error/loaded states via BlocConsumer.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          widget.onApply(code);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer the override error (coupon-apply failed but sheet is intact)
    // over the pricing model's own validity message.
    final String? statusMessage =
        widget.overrideError ??
        (widget.pricing.hasCouponMessage
            ? widget.pricing.couponValidityMessage
            : null);
    final bool isSuccess =
        widget.overrideError == null && widget.pricing.isCouponApplied;
    final rh = ResponsiveHelper.of(context);
    // A little extra height on iPad/fold/tablet — the capped (but still
    // larger) button label needs more room than the base 48dp affords.
    final applyButtonHeight =
        Screen.getVerticalSize(48) + (rh.isLargeScreen ? 14 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                // Use readOnly instead of enabled:false so Flutter does NOT
                // automatically release focus. Releasing focus would dismiss
                // the keyboard, causing viewInsets.bottom → 0 and the sheet
                // visually sliding down.
                readOnly: widget.isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleApply(),
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
                  hintStyle: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                  contentPadding: Screen.getPadding(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.white.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    borderSide: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(12)),
            // Apply button — shows a spinner while loading instead of
            // replacing the whole sheet with a loading shim.
            SizedBox(
              height: applyButtonHeight,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _handleApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.6,
                  ),
                  foregroundColor: AppColors.white,
                  disabledForegroundColor: AppColors.white.withValues(
                    alpha: 0.8,
                  ),
                  elevation: 0,
                  padding: Screen.getPadding(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
                child: widget.isLoading
                    ? SizedBox(
                        width: Screen.getSize(18),
                        height: Screen.getSize(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.alwaysWhite,
                          ),
                        ),
                      )
                    : Text(
                        'Apply',
                        style: AppTypography.bodyTextSemiBold.copyWith(
                          color: AppColors.alwaysWhite,
                          fontSize: ResponsiveHelper.of(
                            context,
                          ).cappedFontSize(18),
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (statusMessage != null) ...[
          SizedBox(height: Screen.getVerticalSize(8)),
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
                size: Screen.getSize(14),
                color: isSuccess ? AppColors.successDark : AppColors.error,
              ),
              SizedBox(width: Screen.getHorizontalSize(6)),
              Expanded(
                child: Text(
                  statusMessage,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: isSuccess ? AppColors.successDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Coupon celebration overlay — confetti burst + savings card shown
// once when a coupon is successfully applied. Inserted on the root
// [Overlay] so it isn't clipped by the sheet's scroll view, and
// auto-dismisses itself after a few seconds.
// ─────────────────────────────────────────────────────────────
class _CouponCelebrationOverlay extends StatefulWidget {
  final double savedAmount;
  final VoidCallback onDismiss;

  const _CouponCelebrationOverlay({
    required this.savedAmount,
    required this.onDismiss,
  });

  @override
  State<_CouponCelebrationOverlay> createState() =>
      _CouponCelebrationOverlayState();
}

class _CouponCelebrationOverlayState extends State<_CouponCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const _visibleDuration = Duration(milliseconds: 2600);

  /// Friendly, easy-to-read lines a student can relate to — kept short
  /// so they read at a glance alongside the saved-amount headline.
  static const _quotes = [
    'Every rupee saved is a rupee closer to your goal!',
    'Smart students always spot the best deals.',
    'That\'s some serious saving skills right there!',
    'Small savings today, bigger dreams tomorrow.',
    'You just made your wallet very happy!',
  ];

  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;
  late final String _quote;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _quote = _quotes[random.nextInt(_quotes.length)];
    _particles = List.generate(28, (_) => _ConfettiParticle.random(random));
    _controller = AnimationController(vsync: this, duration: _visibleDuration)
      ..forward();

    Future.delayed(_visibleDuration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: _CelebrationCard(
                    savedAmount: widget.savedAmount,
                    quote: _quote,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Celebration card — "Coupon Applied!" headline, saved amount, and
// a rotating student-friendly quote.
// ─────────────────────────────────────────────────────────────
class _CelebrationCard extends StatelessWidget {
  final double savedAmount;
  final String quote;

  const _CelebrationCard({required this.savedAmount, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Coupon Applied!',
            textAlign: TextAlign.center,
            style: AppTypography.h5SemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You just saved ₹ ${Utils.formatPrice(savedAmount)}',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            quote,
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Confetti particle model + painter — a lightweight, dependency-free
// falling-confetti effect driven by a single 0..1 [AnimationController].
// ─────────────────────────────────────────────────────────────
class _ConfettiParticle {
  final double x;
  final double startDelay;
  final double fallSpeed;
  final double size;
  final double swayAmplitude;
  final double swayFrequency;
  final double rotationSpeed;
  final Color color;

  const _ConfettiParticle({
    required this.x,
    required this.startDelay,
    required this.fallSpeed,
    required this.size,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.rotationSpeed,
    required this.color,
  });

  static final _colors = [
    AppColors.primary,
    AppColors.discountBadgeBackground,
    AppColors.successDark,
    const Color(0xFFFFC107),
    const Color(0xFFFF6B6B),
  ];

  factory _ConfettiParticle.random(Random random) {
    return _ConfettiParticle(
      x: random.nextDouble(),
      startDelay: random.nextDouble() * 0.25,
      fallSpeed: 0.8 + random.nextDouble() * 0.6,
      size: 6 + random.nextDouble() * 6,
      swayAmplitude: 10 + random.nextDouble() * 20,
      swayFrequency: 2 + random.nextDouble() * 3,
      rotationSpeed:
          (random.nextBool() ? 1 : -1) * (2 + random.nextDouble() * 4),
      color: _colors[random.nextInt(_colors.length)],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localProgress = ((progress - p.startDelay) / (1 - p.startDelay))
          .clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final y = -20 + localProgress * (size.height + 40) * p.fallSpeed;
      if (y > size.height) continue;

      final sway = sin(localProgress * p.swayFrequency * pi * 2) * p.swayAmplitude;
      final dx = p.x * size.width + sway;
      final opacity = localProgress > 0.8 ? (1 - localProgress) / 0.2 : 1.0;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(dx, y);
      canvas.rotate(localProgress * p.rotationSpeed * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
