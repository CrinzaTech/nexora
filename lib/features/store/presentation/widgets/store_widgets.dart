import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';

/// Building blocks shared by every Store screen, so the catalogue, cart,
/// checkout and orders read as one product.

// ── Prices ─────────────────────────────────────────────────────────────

/// Selling price, then — only with a discount — the struck-through MRP
/// and the "% off" in green.
class StorePriceRow extends StatelessWidget {
  final double price;
  final double mrp;
  final int discountPercent;
  final bool large;

  const StorePriceRow({
    super.key,
    required this.price,
    required this.mrp,
    required this.discountPercent,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final priceStyle = large
        ? AppTypography.h4Bold.copyWith(height: 1.1)
        : AppTypography.bodyTextLargeBold.copyWith(height: 1.1);
    final sideStyle = large
        ? AppTypography.bodyTextLargeMedium
        : AppTypography.bodyTextSmallMedium;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: large ? 10 : 6,
      runSpacing: 2,
      children: [
        Text(StoreFormat.money(price), style: priceStyle),
        if (discountPercent > 0) ...[
          Text(
            StoreFormat.money(mrp),
            style: sideStyle.copyWith(
              color: AppColors.mutedTextPrimary,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.mutedTextPrimary,
            ),
          ),
          Text(
            '$discountPercent% off',
            style: sideStyle.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// A small solid pill — "% off", "Bestseller", "New".
class StoreBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StoreBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.alwaysWhite),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// "4.6 ★" on green, then "(38)".
class StoreRatingPill extends StatelessWidget {
  final double rating;
  final int count;
  final bool compact;

  const StoreRatingPill({
    super.key,
    required this.rating,
    required this.count,
    this.compact = true,
  });

  static Color colorFor(double rating) {
    if (rating >= 3.5) return AppColors.successDark;
    if (rating >= 2.5) return AppColors.warningDark;
    return AppColors.errorDark;
  }

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text(
        'No ratings yet',
        style: AppTypography.bodyTextXtraSmallMedium.copyWith(
          color: AppColors.mutedTextPrimary,
        ),
      );
    }
    final style = compact
        ? AppTypography.bodyTextXtraSmallBold
        : AppTypography.bodyTextSmallBold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: colorFor(rating),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                StoreFormat.rating(rating),
                style: style.copyWith(
                  color: AppColors.alwaysWhite,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.star_rounded,
                size: compact ? 11 : 13,
                color: AppColors.alwaysWhite,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '(${StoreFormat.count(count)})',
          style: style.copyWith(
            color: AppColors.mutedTextPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Buttons ────────────────────────────────────────────────────────────

/// The main action on a screen — brand fill, soft glow, spinner while
/// [loading].
class StorePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  const StorePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: enabled ? AppDecorations.ctaGlow() : null,
      ),
      child: Material(
        color: enabled || loading ? AppColors.primaryFill : AppColors.grey200,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 20,
                          color: enabled
                              ? AppColors.onPrimary
                              : AppColors.mutedTextPrimary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.buttonLarge.copyWith(
                            color: enabled
                                ? AppColors.onPrimary
                                : AppColors.mutedTextPrimary,
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
}

/// The secondary action next to [StorePrimaryButton].
class StoreOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  final double height;

  const StoreOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final tone = onPressed == null
        ? AppColors.mutedTextPrimary
        : (color ?? AppColors.primary);
    return SizedBox(
      height: height,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          side: BorderSide(color: tone.withValues(alpha: 0.55), width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: tone,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 19, color: tone),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.buttonLarge.copyWith(
                              color: tone,
                            ),
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

/// Round icon button floating over imagery (the gallery's back / cart).
class StoreGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;

  const StoreGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: AppColors.black,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 21, color: AppColors.textPrimary),
            ),
          ),
        ),
        if (badge != null) Positioned(top: -3, right: -3, child: badge!),
      ],
    );
  }
}

// ── Cart badge ─────────────────────────────────────────────────────────

class StoreCountBadge extends StatelessWidget {
  final int count;

  const StoreCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: count <= 0
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(count),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: AppTypography.bodyTextXtraSmallBold.copyWith(
                  color: AppColors.alwaysWhite,
                  height: 1.1,
                ),
              ),
            ),
    );
  }
}

/// The cart icon with its live badge. Opens the cart.
class StoreCartAction extends StatelessWidget {
  /// Draw as a floating glass disc (over imagery) rather than a plain
  /// app-bar icon.
  final bool glass;

  /// Icon colour for a plain app-bar icon; defaults to the text colour.
  final Color? color;

  const StoreCartAction({super.key, this.glass = false, this.color});

  @override
  Widget build(BuildContext context) {
    final count = context.select<StoreCartCubit, int>((c) => c.state.count);
    void open() => context.push(AppRoutes.storeCart);
    if (glass) {
      return StoreGlassIconButton(
        icon: Icons.shopping_bag_outlined,
        onTap: open,
        badge: StoreCountBadge(count: count),
      );
    }
    return IconButton(
      tooltip: 'Cart',
      onPressed: open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            color: color ?? AppColors.textPrimary,
          ),
          Positioned(top: -6, right: -8, child: StoreCountBadge(count: count)),
        ],
      ),
    );
  }
}

// ── Quantity ───────────────────────────────────────────────────────────

/// − qty + . Disables at 1 and [max]; [onRemove], when given, replaces
/// the minus with a bin at qty 1.
class StoreQtyStepper extends StatelessWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;
  final VoidCallback? onRemove;
  final bool busy;
  final bool dense;

  const StoreQtyStepper({
    super.key,
    required this.qty,
    required this.max,
    required this.onChanged,
    this.onRemove,
    this.busy = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = dense ? 30.0 : 36.0;
    final canDec = !busy && (qty > 1 || onRemove != null);
    final canInc = !busy && qty < max;
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: dense ? 16 : 18,
          color: enabled ? AppColors.primary : AppColors.grey300,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerLight, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            qty <= 1 && onRemove != null
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            canDec,
            () => qty <= 1 ? onRemove?.call() : onChanged(qty - 1),
          ),
          SizedBox(
            width: dense ? 26 : 32,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Text('$qty', style: AppTypography.bodyTextBold),
            ),
          ),
          btn(Icons.add_rounded, canInc, () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

// ── Sections ───────────────────────────────────────────────────────────

class StoreSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const StoreSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 8, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h6Bold),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: AppTypography.bodyTextSmallBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled white panel used down every detail screen.
class StorePanel extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const StorePanel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      margin: margin,
      padding: padding,
      radius: AppSizes.radiusL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!, style: AppTypography.bodyTextLargeBold),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// One line of a bill: label on the left, amount on the right.
class StoreBillRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final bool emphasis;

  const StoreBillRow({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasis
        ? AppTypography.bodyTextLargeBold
        : AppTypography.bodyTextMedium.copyWith(color: AppColors.textSecondary);
    final valueStyle = emphasis
        ? AppTypography.h6Bold
        : AppTypography.bodyTextSemiBold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                if (hint != null)
                  Text(
                    hint!,
                    style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: valueStyle.copyWith(color: valueColor ?? valueStyle.color),
          ),
        ],
      ),
    );
  }
}

/// A dashed hairline, the receipt-style divider used above a total.
class StoreDashedDivider extends StatelessWidget {
  const StoreDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final n = (c.maxWidth / 8).floor();
          return Row(
            children: List.generate(
              n,
              (_) => Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: AppColors.dividerLight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Green "You save ₹120 on this order" strip.
class StoreSavingsBanner extends StatelessWidget {
  final double savings;
  final String suffix;

  const StoreSavingsBanner({
    super.key,
    required this.savings,
    this.suffix = 'on this order',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'You save '),
                  TextSpan(
                    text: StoreFormat.money(savings),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' $suffix'),
                ],
              ),
              style: AppTypography.bodyTextSmallSemiBold.copyWith(
                color: AppColors.successDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red line under a cart / checkout line with a problem.
class StoreIssueText extends StatelessWidget {
  final String message;

  const StoreIssueText({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodyTextSmallSemiBold.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Order status ───────────────────────────────────────────────────────

/// Colour and icon for an order's `status.key`.
(Color, IconData) storeStatusTone(StoreOrderStatus status) {
  switch (status.key) {
    case 'placed':
      return (AppColors.info, Icons.receipt_long_rounded);
    case 'confirmed':
      return (AppColors.primary, Icons.inventory_2_rounded);
    case 'shipped':
      return (AppColors.warningDark, Icons.local_shipping_rounded);
    case 'delivered':
      return (AppColors.success, Icons.check_circle_rounded);
    case 'cancelled':
      return (AppColors.error, Icons.cancel_rounded);
    default:
      return (AppColors.grey500, Icons.schedule_rounded);
  }
}

class StoreStatusChip extends StatelessWidget {
  final StoreOrderStatus status;

  const StoreStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = storeStatusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / error / loading ────────────────────────────────────────────

class StoreEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StoreEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.16),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Icon(icon, size: 46, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h6Bold,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: StorePrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: 48,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StoreErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const StoreErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StoreEmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Something went wrong',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

/// Shimmer block for skeletons.
class StoreSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const StoreSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.grey200,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Spinner row at the end of an infinite list.
class StoreLoadMoreIndicator extends StatelessWidget {
  const StoreLoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Fixed bottom bar holding a screen's main action, lifted off the page.
class StoreBottomBar extends StatelessWidget {
  final Widget child;

  const StoreBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(
              alpha: AppColors.isDark ? 0.4 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.isDark
                ? AppColors.alwaysWhite.withValues(alpha: 0.06)
                : AppColors.dividerLight.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

/// Scroll-end trigger for infinite lists: fires [onLoadMore] when the
/// learner nears the bottom.
bool storeOnScrollEnd(ScrollNotification n, VoidCallback onLoadMore) {
  if (n.metrics.axis == Axis.vertical &&
      n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
    onLoadMore();
  }
  return false;
}
