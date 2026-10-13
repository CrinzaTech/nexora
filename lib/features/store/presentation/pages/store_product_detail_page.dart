import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/bloc/store_product_detail_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_media_gallery.dart';
import 'package:nexora/features/store/presentation/widgets/store_review_tile.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Product page (C4).
class StoreProductDetailPage extends StatelessWidget {
  final String productId;

  const StoreProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoreProductDetailCubit>()..load(productId),
      child: _DetailView(productId: productId),
    );
  }
}

class _DetailView extends StatelessWidget {
  final String productId;

  const _DetailView({required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreProductDetailCubit, StoreProductDetailState>(
      builder: (context, state) {
        return state.when(
          loading: () => const _DetailSkeleton(),
          error: (message, notFound) => Scaffold(
            backgroundColor: AppColors.scaffoldLight,
            appBar: AppBar(
              backgroundColor: AppColors.scaffoldLight,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 30,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            body: notFound
                ? StoreEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Product not found',
                    message: message,
                    actionLabel: 'Back to store',
                    onAction: () => context.pop(),
                  )
                : StoreErrorView(
                    message: message,
                    onRetry: () =>
                        context.read<StoreProductDetailCubit>().load(productId),
                  ),
          ),
          loaded: (product) => _ProductBody(product: product),
        );
      },
    );
  }
}

class _ProductBody extends StatefulWidget {
  final StoreProductDetail product;

  const _ProductBody({required this.product});

  @override
  State<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends State<_ProductBody> {
  final _reviewsKey = GlobalKey();
  int _qty = 1;

  StoreProductDetail get p => widget.product;

  /// The cart is the live answer once it has been read; the product
  /// payload's `cartQty` until then.
  int _inCart(StoreCartState cart) =>
      cart.cart == null ? p.cartQty : cart.qtyOf(p.productId);

  Future<void> _addToCart() async {
    final error = await context.read<StoreCartCubit>().setQty(
      p.productId,
      _qty,
    );
    if (!mounted) return;
    if (error != null) {
      CustomSnackbar.error(context, title: 'Couldn’t add', message: error);
      // Stock may have moved; the page should show what is true now.
      context.read<StoreProductDetailCubit>().load(p.productId, silent: true);
      return;
    }
    HapticFeedback.mediumImpact();
    CustomSnackbar.success(
      context,
      title: 'Added to cart',
      message: '${p.card.title} × $_qty',
    );
  }

  void _buyNow() {
    context.push(
      '${AppRoutes.storeCheckout}'
      '?productId=${Uri.encodeComponent(p.productId)}&qty=$_qty',
    );
  }

  void _scrollToReviews() {
    final ctx = _reviewsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final galleryHeight = (width * 0.95).clamp(280.0, 520.0);
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          color: AppColors.primary,
          edgeOffset: topInset,
          onRefresh: () => context.read<StoreProductDetailCubit>().load(
            p.productId,
            silent: true,
          ),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: galleryHeight,
                backgroundColor: AppColors.white,
                surfaceTintColor: AppColors.white,
                automaticallyImplyLeading: false,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: StoreGlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                actions: const [
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(child: StoreCartAction(glass: true)),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: StoreMediaGallery(
                      media: p.media,
                      fallbackImageUrl: p.card.imageUrl,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _summary(context)),
              SliverToBoxAdapter(child: _deliveryPanel()),
              if (p.warranty != null || p.guarantee != null)
                SliverToBoxAdapter(child: _coverPanel()),
              if (p.description.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: StorePanel(
                    title: 'About this item',
                    child: _ExpandableText(text: p.description),
                  ),
                ),
              SliverToBoxAdapter(child: _specsPanel()),
              SliverToBoxAdapter(
                key: _reviewsKey,
                child: _reviewsPanel(context),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<StoreCartCubit, StoreCartState>(
        builder: (context, cart) => _bottomBar(context, cart),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final card = p.card;
    final eyebrow = [
      if (p.brand != null) p.brand!,
      if (card.categoryName != null) card.categoryName!,
    ].join('  ·  ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(
              alpha: AppColors.isDark ? 0.3 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow.isNotEmpty)
            Text(
              eyebrow.toUpperCase(),
              style: AppTypography.bodyTextXtraSmallBold.copyWith(
                color: AppColors.primary,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 6),
          Text(card.title, style: AppTypography.h5Bold.copyWith(height: 1.25)),
          if (card.shortDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              card.shortDescription!,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: _scrollToReviews,
                child: StoreRatingPill(
                  rating: p.rating.average,
                  count: p.rating.count,
                  compact: false,
                ),
              ),
              if (card.isTrending)
                const StoreBadge(
                  label: 'Trending',
                  color: AppColors.warningDark,
                  icon: Icons.local_fire_department_rounded,
                ),
              if (card.isNew)
                const StoreBadge(label: 'New', color: AppColors.infoDark),
            ],
          ),
          const SizedBox(height: 16),
          StorePriceRow(
            price: card.sellingPrice,
            mrp: card.mrp,
            discountPercent: card.discountPercent,
            large: true,
          ),
          const SizedBox(height: 4),
          Text(
            'Inclusive of all taxes',
            style: AppTypography.bodyTextSmallMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _stockLine(),
          if (card.inStock && p.maxQtyPerOrder > 1) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Quantity', style: AppTypography.bodyTextSemiBold),
                const Spacer(),
                StoreQtyStepper(
                  qty: _qty,
                  max: p.maxQtyPerOrder,
                  onChanged: (q) => setState(() => _qty = q),
                ),
              ],
            ),
            if (_qty >= p.maxQtyPerOrder)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'You can order up to ${p.maxQtyPerOrder} at a time.',
                  style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stockLine() {
    final card = p.card;
    final (String text, Color color, IconData icon) line = !card.inStock
        ? ('Out of stock', AppColors.error, Icons.remove_shopping_cart_outlined)
        : card.onlyLeft != null
        ? (
            'Hurry, only ${card.onlyLeft} left in stock',
            AppColors.warningDark,
            Icons.bolt_rounded,
          )
        : ('In stock', AppColors.success, Icons.check_circle_outline_rounded);
    return Row(
      children: [
        Icon(line.$3, size: 18, color: line.$2),
        const SizedBox(width: 6),
        Text(
          line.$1,
          style: AppTypography.bodyTextSemiBold.copyWith(color: line.$2),
        ),
      ],
    );
  }

  Widget _deliveryPanel() {
    final d = p.delivery;
    final window = d == null ? null : StoreFormat.dateRange(d.from, d.to);
    return StorePanel(
      title: 'Delivery & policies',
      child: Column(
        children: [
          if (d != null)
            _InfoRow(
              icon: Icons.local_shipping_outlined,
              title: window != null
                  ? 'Delivery by $window'
                  : 'Delivers in ${d.minDays} to ${d.maxDays} days',
              subtitle: d.free || d.charge == 0
                  ? 'FREE delivery'
                  : '${StoreFormat.money(d.charge)} delivery charge',
              subtitleColor: d.free || d.charge == 0 ? AppColors.success : null,
            ),
          _InfoRow(
            icon: p.isCancellable
                ? Icons.event_busy_outlined
                : Icons.do_not_disturb_alt_outlined,
            title: p.isCancellable
                ? 'Cancellable before it ships'
                : 'Can’t be cancelled once ordered',
            subtitle: p.isCancellable
                ? 'Cancelled orders are refunded in full'
                : null,
          ),
          _InfoRow(
            icon: p.isReturnable
                ? Icons.assignment_return_outlined
                : Icons.block_outlined,
            title: p.isReturnable
                ? '${p.returnWindowDays}-day returns'
                : 'Not returnable',
          ),
          if (p.sellerName != null)
            _InfoRow(
              icon: Icons.storefront_outlined,
              title: 'Sold by ${p.sellerName}',
              subtitle: 'Shipped by your academy',
              last: true,
            ),
        ],
      ),
    );
  }

  Widget _coverPanel() {
    return StorePanel(
      title: 'Warranty & guarantee',
      child: Column(
        children: [
          if (p.warranty != null)
            _CoverCard(
              cover: p.warranty!,
              kind: 'warranty',
              promise: 'Defects are repaired',
              icon: Icons.build_circle_outlined,
              color: AppColors.info,
            ),
          if (p.warranty != null && p.guarantee != null)
            const SizedBox(height: 10),
          if (p.guarantee != null)
            _CoverCard(
              cover: p.guarantee!,
              kind: 'guarantee',
              promise: 'Replaced or refunded',
              icon: Icons.verified_outlined,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  Widget _specsPanel() {
    final card = p.card;
    final category = [
      if (p.parentCategoryName != null) p.parentCategoryName!,
      if (card.categoryName != null) card.categoryName!,
    ].join(' › ');
    final rows = <(String, String)>[
      if (p.brand != null) ('Brand', p.brand!),
      if (category.isNotEmpty) ('Category', category),
      if (p.countryOfOrigin != null) ('Country of origin', p.countryOfOrigin!),
      if (p.sellerName != null) ('Sold by', p.sellerName!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return StorePanel(
      title: 'Product details',
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: AppColors.dividerLight)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      rows[i].$1,
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: AppTypography.bodyTextSemiBold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _reviewsPanel(BuildContext context) {
    final rating = p.rating;
    void seeAll() => context.push(
      '${AppRoutes.storeReviews}?id=${Uri.encodeComponent(p.productId)}'
      '&title=${Uri.encodeComponent(p.card.title)}',
    );
    return StorePanel(
      title: 'Ratings & reviews',
      child: rating.count == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    color: AppColors.mutedTextPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No ratings yet. Buyers can rate this product once it '
                      'reaches them.',
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StoreRatingSummaryView(rating: rating),
                if (p.topReviews.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (var i = 0; i < p.topReviews.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: AppColors.dividerLight),
                    StoreReviewTile(review: p.topReviews[i]),
                  ],
                ],
                const SizedBox(height: 6),
                StoreOutlinedButton(
                  label: 'See all reviews',
                  icon: Icons.forum_outlined,
                  height: 46,
                  onPressed: seeAll,
                ),
              ],
            ),
    );
  }

  Widget _bottomBar(BuildContext context, StoreCartState cart) {
    final card = p.card;
    if (!card.inStock) {
      return const StoreBottomBar(
        child: StorePrimaryButton(
          label: 'Out of stock',
          onPressed: null,
          icon: Icons.remove_shopping_cart_outlined,
        ),
      );
    }
    final inCart = _inCart(cart);
    final busy = cart.isBusy(p.productId);
    return StoreBottomBar(
      child: Row(
        children: [
          Expanded(
            child: inCart > 0
                ? StoreOutlinedButton(
                    label: 'In cart ($inCart)',
                    icon: Icons.shopping_bag_rounded,
                    onPressed: () => context.push(AppRoutes.storeCart),
                  )
                : StoreOutlinedButton(
                    label: 'Add to cart',
                    icon: Icons.add_shopping_cart_rounded,
                    loading: busy,
                    onPressed: _addToCart,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StorePrimaryButton(
              label: 'Buy now',
              icon: Icons.flash_on_rounded,
              onPressed: _buyNow,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Text(title, style: AppTypography.bodyTextSemiBold),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: subtitleColor ?? AppColors.mutedTextPrimary,
                      fontWeight: subtitleColor != null
                          ? FontWeight.w700
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  final StoreCover cover;
  final String kind;
  final String promise;
  final IconData icon;
  final Color color;

  const _CoverCard({
    required this.cover,
    required this.kind,
    required this.promise,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final by = cover.providedBy == null ? '' : ' · by ${cover.providedBy}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${StoreFormat.coverLength(cover.months)} $kind',
                  style: AppTypography.bodyTextBold,
                ),
                Text(
                  '$promise$by',
                  style: AppTypography.bodyTextSmallSemiBold.copyWith(
                    color: color,
                  ),
                ),
                if (cover.terms != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    cover.terms!,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain-text description that keeps its line breaks, folded to five
/// lines until asked.
class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyTextMedium.copyWith(
      color: AppColors.textSecondary,
      height: 1.55,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 5,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : 5,
                overflow: _expanded ? null : TextOverflow.fade,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  StoreSkeletonBox(height: width * 0.9, radius: 0),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: StoreGlassIconButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => context.pop(),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StoreSkeletonBox(width: 100, height: 10),
                    SizedBox(height: 12),
                    StoreSkeletonBox(height: 22),
                    SizedBox(height: 8),
                    StoreSkeletonBox(width: 220, height: 22),
                    SizedBox(height: 16),
                    StoreSkeletonBox(width: 80, height: 18),
                    SizedBox(height: 16),
                    StoreSkeletonBox(width: 160, height: 30),
                    SizedBox(height: 24),
                    StoreSkeletonBox(height: 120, radius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
