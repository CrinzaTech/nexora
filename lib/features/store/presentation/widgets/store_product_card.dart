import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

// ── Geometry ───────────────────────────────────────────────────────────

/// Card corner and the inset around the artwork panel.
const double _cardRadius = 18;
const double _inset = 6;

/// Width ÷ height of the artwork panel. A little taller than square: most
/// of the catalogue is book covers and kits shot in portrait.
const double _artAspect = 0.9;

/// Height of the text block under the artwork. Grids and rails need a
/// fixed extent, so it follows the app's font scale and the learner's
/// text-size setting rather than clipping the price.
///
/// The font scale is read off a real body size: `getFontSize` clamps to a
/// minimum of 8, so `getFontSize(1)` would answer 8, an 8× scale.
double storeCardInfoHeight(BuildContext context) {
  final fontScale = Screen.getFontSize(14) / 14;
  return MediaQuery.textScalerOf(context).scale(124 * fontScale);
}

/// Full height of a [StoreProductTile] that is [width] wide.
double storeTileExtent(BuildContext context, double width) =>
    _inset + (width - _inset * 2) / _artAspect + storeCardInfoHeight(context);

/// Two-across grid geometry shared by every product grid.
SliverGridDelegate storeProductGridDelegate(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
  const gap = 12.0;
  final tile = (width - 32 - gap * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: gap + 2,
    crossAxisSpacing: gap,
    mainAxisExtent: storeTileExtent(context, tile),
  );
}

void _openProduct(BuildContext context, StoreProductCard p) => context.push(
  '${AppRoutes.storeProduct}?id=${Uri.encodeComponent(p.productId)}',
);

/// The card's surface. Light mode gets a deeper, layered shadow than the
/// app's standard card so the tiles lift off the page: a wide soft drop,
/// a tighter mid shadow, and a hairline contact shadow at the base. Dark
/// mode keeps the shared treatment, since black shadows barely read on a
/// dark page.
BoxDecoration _cardDecoration() => AppDecorations.card(
  radius: _cardRadius,
  shadows: AppColors.isDark
      ? null
      : [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
);

// ── Tile ───────────────────────────────────────────────────────────────

/// The product tile used in rails and grids (ProductCard in the API):
/// the product on an inset studio panel, then category and rating, a
/// two-line title, the price and one line of urgency or reassurance.
class StoreProductTile extends StatelessWidget {
  final StoreProductCard product;

  const StoreProductTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return DecoratedBox(
      decoration: _cardDecoration(),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProduct(context, p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, 0),
                child: AspectRatio(
                  aspectRatio: _artAspect,
                  child: _Artwork(product: p, showQuickAdd: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 0),
                child: _Info(product: p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single product given a whole row: artwork left, details right. Used
/// when a rail holds only one product, so the row isn't half empty.
class StoreProductWideTile extends StatelessWidget {
  final StoreProductCard product;

  const StoreProductWideTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final artWidth = (MediaQuery.sizeOf(context).width * 0.36).clamp(
      120.0,
      190.0,
    );
    return DecoratedBox(
      decoration: _cardDecoration(),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProduct(context, p),
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: artWidth,
                  child: AspectRatio(
                    aspectRatio: _artAspect,
                    child: _Artwork(product: p, showQuickAdd: false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Info(product: p, titleLines: 3),
                        if (p.shortDescription != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            p.shortDescription!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextXtraSmallMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (p.inStock)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _QuickAdd(product: p, wide: true),
                          ),
                      ],
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

// ── Artwork ────────────────────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  final StoreProductCard product;
  final bool showQuickAdd;

  const _Artwork({required this.product, required this.showQuickAdd});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final dark = AppColors.isDark;
    final tag = p.isTrending
        ? (
            Icons.local_fire_department_rounded,
            'Trending',
            AppColors.warningDark,
          )
        : p.isNew
        ? (Icons.auto_awesome_rounded, 'New', AppColors.infoDark)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius - _inset + 2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A soft studio backdrop, so covers of every size sit on the
          // same surface instead of being cropped to fit.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [AppColors.grey100, AppColors.grey50]
                    : const [Color(0xFFF7F7FB), Color(0xFFEDEEF4)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: CustomNetworkImage(
              url: p.imageUrl,
              fit: BoxFit.contain,
              placeholder: const SizedBox.shrink(),
              errorWidget: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.grey300,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.hasDiscount)
                  _Chip(
                    label: '${p.discountPercent}% OFF',
                    fg: AppColors.alwaysWhite,
                    bg: AppColors.successDark,
                  ),
                const Spacer(),
                if (tag != null)
                  _Chip(
                    label: tag.$2,
                    icon: tag.$1,
                    fg: tag.$3,
                    bg: AppColors.alwaysWhite.withValues(alpha: 0.92),
                  ),
              ],
            ),
          ),
          if (p.hasVideo)
            Positioned(
              left: 8,
              bottom: 8,
              child: _Chip(
                label: 'Video',
                icon: Icons.play_arrow_rounded,
                fg: AppColors.alwaysWhite,
                bg: AppColors.black.withValues(alpha: 0.55),
              ),
            ),
          if (!p.inStock)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.white.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Chip(
                      label: 'Out of stock',
                      fg: AppColors.white,
                      bg: AppColors.grey800,
                    ),
                  ),
                ),
              ),
            )
          else if (showQuickAdd)
            Positioned(right: 8, bottom: 8, child: _QuickAdd(product: p)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg;
  final Color bg;

  const _Chip({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: fg,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick add ──────────────────────────────────────────────────────────

/// A round + that adds one to the cart, becoming a − n + stepper once the
/// product is in it. Quantities always come from the cart the server
/// returned; nothing here is guessed.
class _QuickAdd extends StatelessWidget {
  final StoreProductCard product;

  /// The larger "Add to cart" pill used on the wide tile.
  final bool wide;

  const _QuickAdd({required this.product, this.wide = false});

  Future<void> _change(BuildContext context, int delta) async {
    final cubit = context.read<StoreCartCubit>();
    final id = product.productId;
    // K2 *sets* the quantity, so the current one must be known first:
    // adding "1" to an unread cart could shrink a line of 3 down to 1.
    if (cubit.state.cart == null) await cubit.load(silent: true);
    if (cubit.state.cart == null) {
      if (context.mounted) {
        CustomSnackbar.error(
          context,
          title: 'Cart not updated',
          message: cubit.state.error ?? 'Please try again.',
        );
      }
      return;
    }
    final target = (cubit.state.qtyOf(id) + delta).clamp(0, 999);
    HapticFeedback.selectionClick();
    final error = await cubit.setQty(id, target);
    if (error != null && context.mounted) {
      CustomSnackbar.error(context, title: 'Cart not updated', message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = product.productId;
    final qty = context.select<StoreCartCubit, int>((c) => c.state.qtyOf(id));
    final busy = context.select<StoreCartCubit, bool>(
      (c) => c.state.isBusy(id),
    );

    final shadow = [
      BoxShadow(
        color: AppColors.black.withValues(alpha: 0.16),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

    if (qty > 0) {
      Widget step(IconData icon, int delta) => InkResponse(
        onTap: busy ? null : () => _change(context, delta),
        radius: 18,
        child: SizedBox(
          width: wide ? 36 : 30,
          height: wide ? 36 : 30,
          child: Icon(icon, size: 16, color: AppColors.onPrimary),
        ),
      );
      return Container(
        decoration: BoxDecoration(
          color: AppColors.primaryFill,
          borderRadius: BorderRadius.circular(20),
          boxShadow: shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            step(
              qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
              -1,
            ),
            SizedBox(
              width: 20,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(
                        '$qty',
                        style: AppTypography.bodyTextSmallBold.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
              ),
            ),
            step(Icons.add_rounded, 1),
          ],
        ),
      );
    }

    if (wide) {
      return Material(
        color: AppColors.primaryFill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: busy ? null : () => _change(context, 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 16,
                        color: AppColors.onPrimary,
                      ),
                const SizedBox(width: 6),
                Text(
                  'Add to cart',
                  style: AppTypography.bodyTextSmallBold.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.alwaysWhite,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : () => _change(context, 1),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow),
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                )
              : Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: AppColors.brandPrimary,
                ),
        ),
      ),
    );
  }
}

// ── Text block ─────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final StoreProductCard product;
  final int titleLines;

  const _Info({required this.product, this.titleLines = 2});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (p.categoryName ?? '').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextXtraSmallBold.copyWith(
                  color: AppColors.mutedTextPrimary,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            if (p.ratingCount > 0) ...[
              const Icon(
                Icons.star_rounded,
                size: 13,
                color: AppColors.ratingColor,
              ),
              const SizedBox(width: 2),
              Text(
                StoreFormat.rating(p.ratingAvg),
                style: AppTypography.bodyTextXtraSmallBold,
              ),
              Text(
                ' (${StoreFormat.count(p.ratingCount)})',
                style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Padded with line breaks so a one-line title still takes the
        // full height, and every card in a row lines up.
        Text(
          '${p.title}${'\n' * (titleLines - 1)}',
          maxLines: titleLines,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyTextSmallSemiBold.copyWith(height: 1.3),
        ),
        const SizedBox(height: 7),
        _CardPrice(product: p),
        const SizedBox(height: 4),
        _Footnote(product: p),
      ],
    );
  }
}

/// Price and, with a discount, the struck-through MRP, on one line. The
/// "% OFF" lives on the artwork, so it isn't repeated here.
class _CardPrice extends StatelessWidget {
  final StoreProductCard product;

  const _CardPrice({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          StoreFormat.money(p.sellingPrice),
          maxLines: 1,
          style: AppTypography.bodyTextXtraLargeBold.copyWith(
            height: 1.1,
            letterSpacing: -0.2,
          ),
        ),
        if (p.hasDiscount) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              StoreFormat.money(p.mrp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One line of urgency or reassurance under the price. Always takes its
/// line, so cards stay level.
class _Footnote extends StatelessWidget {
  final StoreProductCard product;

  const _Footnote({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final (String text, Color color, IconData icon)? line = !p.inStock
        ? (
            'Currently unavailable',
            AppColors.mutedTextPrimary,
            Icons.block_rounded,
          )
        : p.onlyLeft != null
        ? ('Only ${p.onlyLeft} left', AppColors.warningDark, Icons.bolt_rounded)
        : p.freeDelivery
        ? ('Free delivery', AppColors.success, Icons.local_shipping_outlined)
        : null;
    final style = AppTypography.bodyTextXtraSmallBold;
    if (line == null) return Text(' ', style: style);
    return Row(
      children: [
        Icon(line.$3, size: 12, color: line.$2),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            line.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: line.$2),
          ),
        ),
      ],
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────

/// Grid placeholder while the first page loads.
class StoreProductTileSkeleton extends StatelessWidget {
  const StoreProductTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            AspectRatio(
              aspectRatio: _artAspect,
              child: StoreSkeletonBox(height: double.infinity, radius: 14),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(5, 10, 5, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreSkeletonBox(width: 50, height: 9),
                  SizedBox(height: 8),
                  StoreSkeletonBox(height: 12),
                  SizedBox(height: 5),
                  StoreSkeletonBox(width: 90, height: 12),
                  SizedBox(height: 10),
                  StoreSkeletonBox(width: 70, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rail ───────────────────────────────────────────────────────────────

/// A home rail (Trending, New arrivals, …), shaped by how much it holds:
/// one product gets a wide feature card, two share the row, more scroll.
class StoreProductRail extends StatelessWidget {
  final List<StoreProductCard> products;

  const StoreProductRail({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    // Room below for the card shadow: a scrolling rail clips at its edges.
    const pad = EdgeInsets.fromLTRB(16, 4, 16, 26);

    if (products.length == 1) {
      return Padding(
        padding: pad,
        child: StoreProductWideTile(product: products.first),
      );
    }

    if (products.length == 2) {
      final tile = (screen - 32 - 12) / 2;
      return Padding(
        padding: pad,
        child: SizedBox(
          height: storeTileExtent(context, tile),
          child: Row(
            children: [
              Expanded(child: StoreProductTile(product: products[0])),
              const SizedBox(width: 12),
              Expanded(child: StoreProductTile(product: products[1])),
            ],
          ),
        ),
      );
    }

    // Shows two and a half cards, so the row reads as scrollable.
    final width = (screen * 0.42).clamp(150.0, 220.0);
    return SizedBox(
      height: storeTileExtent(context, width) + pad.vertical,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: pad,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: width,
          child: StoreProductTile(product: products[i]),
        ),
      ),
    );
  }
}
