import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/bloc/store_home_cubit.dart';
import 'package:nexora/features/store/presentation/bloc/store_products_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_product_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Store home (C1 + C3): featured carousel, category chips, the rails, and
/// every product in an infinite grid underneath.
class StoreHomePage extends StatelessWidget {
  const StoreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            // Quick add needs current quantities (K2 sets, not adds).
            sl<StoreCartCubit>().load(silent: true);
            return sl<StoreHomeCubit>()..load();
          },
        ),
        BlocProvider(
          create: (_) =>
              sl<StoreProductsCubit>()..load(const StoreProductQuery()),
        ),
      ],
      child: const _StoreHomeView(),
    );
  }
}

class _StoreHomeView extends StatelessWidget {
  const _StoreHomeView();

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<StoreHomeCubit>().load(),
      context.read<StoreProductsCubit>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      body: BlocBuilder<StoreHomeCubit, StoreHomeState>(
        builder: (context, state) {
          final storeName = state.maybeWhen(
            loaded: (home) => home.storeName,
            orElse: () => 'Store',
          );
          return NotificationListener<ScrollNotification>(
            onNotification: (n) => storeOnScrollEnd(
              n,
              context.read<StoreProductsCubit>().loadMore,
            ),
            child: RefreshIndicator(
              color: AppColors.primary,
              edgeOffset: 150,
              onRefresh: () => _refresh(context),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _StoreHeader(storeName: storeName),
                  ...state.when(
                    initial: () => [const _HomeSkeleton()],
                    loading: () => [const _HomeSkeleton()],
                    unavailable: () => const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: StoreEmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Store isn’t available',
                          message:
                              'Your academy hasn’t opened its store yet. '
                              'Check back later.',
                        ),
                      ),
                    ],
                    error: (message) => [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: StoreErrorView(
                          message: message,
                          onRetry: () => _refresh(context),
                        ),
                      ),
                    ],
                    loaded: (home) => [
                      ..._homeSlivers(context, home),
                      const _AllProductsSlivers(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _homeSlivers(BuildContext context, StoreHome home) {
    void seeAll(String title, StoreSort sort) => context.push(
      '${AppRoutes.storeProducts}?title=${Uri.encodeComponent(title)}'
      '&sort=${sort.wire}',
    );
    return [
      if (home.categories.isNotEmpty)
        SliverToBoxAdapter(child: _CategoryStrip(categories: home.categories)),
      if (home.featured.isNotEmpty)
        SliverToBoxAdapter(child: _FeaturedCarousel(products: home.featured)),
      SliverToBoxAdapter(child: _TrustStrip(storeName: home.storeName)),
      if (home.trending.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: StoreSectionHeader(
            title: 'Trending now',
            subtitle: 'What learners are buying this week',
            actionLabel: 'See all',
            onAction: () => seeAll('Trending now', StoreSort.popular),
          ),
        ),
        SliverToBoxAdapter(child: StoreProductRail(products: home.trending)),
      ],
      if (home.newArrivals.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: StoreSectionHeader(
            title: 'New arrivals',
            subtitle: 'Fresh on the shelves',
            actionLabel: 'See all',
            onAction: () => seeAll('New arrivals', StoreSort.newest),
          ),
        ),
        SliverToBoxAdapter(child: StoreProductRail(products: home.newArrivals)),
      ],
      if (home.bestsellers.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: StoreSectionHeader(
            title: 'Bestsellers',
            subtitle: 'Top picks from your academy',
            actionLabel: 'See all',
            onAction: () => seeAll('Bestsellers', StoreSort.popular),
          ),
        ),
        SliverToBoxAdapter(child: StoreProductRail(products: home.bestsellers)),
      ],
    ];
  }
}

// ── Header ─────────────────────────────────────────────────────────────

class _StoreHeader extends StatelessWidget {
  final String storeName;

  const _StoreHeader({required this.storeName});

  @override
  Widget build(BuildContext context) {
    const onBrand = AppColors.alwaysWhite;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 150,
      backgroundColor: AppColors.brandPrimary,
      surfaceTintColor: AppColors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.chevron_left_rounded, color: onBrand, size: 30),
      ),
      titleSpacing: 0,
      title: Text(
        storeName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.h6Bold.copyWith(color: onBrand),
      ),
      actions: [
        IconButton(
          tooltip: 'My orders',
          onPressed: () => context.push(AppRoutes.storeOrders),
          icon: const Icon(Icons.receipt_long_outlined, color: onBrand),
        ),
        const StoreCartAction(color: onBrand),
        const SizedBox(width: 6),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Stack(
            children: [
              // Two soft discs give the flat gradient some depth.
              Positioned(
                right: -40,
                top: -30,
                child: _Glow(size: 170, alpha: 0.12),
              ),
              Positioned(
                left: -50,
                bottom: 10,
                child: _Glow(size: 130, alpha: 0.08),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 74,
                child: Text(
                  'Books, kits & more, delivered to your door',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: onBrand.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _SearchPill(
            onTap: () => context.push('${AppRoutes.storeProducts}?search=1'),
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final double alpha;

  const _Glow({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.alwaysWhite.withValues(alpha: alpha),
    ),
  );
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search books, kits, brands…',
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
              Icon(Icons.tune_rounded, size: 20, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Categories ─────────────────────────────────────────────────────────

class _CategoryStrip extends StatelessWidget {
  final List<StoreCategory> categories;

  const _CategoryStrip({required this.categories});

  static const _fallbackIcons = <IconData>[
    Icons.menu_book_rounded,
    Icons.science_outlined,
    Icons.edit_note_rounded,
    Icons.backpack_outlined,
    Icons.checkroom_rounded,
    Icons.calculate_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    // Top level only; a category already includes its sub-categories.
    final top = categories.where((c) => c.parentId == null).toList();
    final shown = top.isEmpty ? categories : top;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final c = shown[i];
          return InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            onTap: () => context.push(
              '${AppRoutes.storeProducts}?categoryId=${c.id}'
              '&title=${Uri.encodeComponent(c.name)}',
            ),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      boxShadow: AppDecorations.cardShadow(),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: c.iconUrl != null
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CustomNetworkImage(
                              url: c.iconUrl,
                              fit: BoxFit.contain,
                              errorWidget: _fallback(i),
                            ),
                          )
                        : _fallback(i),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyTextXtraSmallBold,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fallback(int i) => Icon(
    _fallbackIcons[i % _fallbackIcons.length],
    color: AppColors.primary,
    size: 26,
  );
}

// ── Featured ───────────────────────────────────────────────────────────

class _FeaturedCarousel extends StatefulWidget {
  final List<StoreProductCard> products;

  const _FeaturedCarousel({required this.products});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.products.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.products.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _controller,
              itemCount: products.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _FeaturedSlide(product: products[i]),
              ),
            ),
          ),
          if (products.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < products.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.grey200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedSlide extends StatelessWidget {
  final StoreProductCard product;

  const _FeaturedSlide({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    const onDark = AppColors.alwaysWhite;
    return GestureDetector(
      onTap: () => context.push(
        '${AppRoutes.storeProduct}?id=${Uri.encodeComponent(p.productId)}',
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: AppDecorations.cardShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomNetworkImage(url: p.imageUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.black.withValues(alpha: 0.78),
                    AppColors.black.withValues(alpha: 0.45),
                    AppColors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 110, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreBadge(
                    label: 'FEATURED',
                    color: AppColors.accent,
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const Spacer(),
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextXtraLargeBold.copyWith(
                      color: onDark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        StoreFormat.money(p.sellingPrice),
                        style: AppTypography.bodyTextLargeBold.copyWith(
                          color: onDark,
                        ),
                      ),
                      if (p.hasDiscount) ...[
                        const SizedBox(width: 8),
                        Text(
                          StoreFormat.money(p.mrp),
                          style: AppTypography.bodyTextSmallMedium.copyWith(
                            color: onDark.withValues(alpha: 0.7),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: onDark.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${p.discountPercent}% off',
                          style: AppTypography.bodyTextSmallBold.copyWith(
                            color: AppColors.successLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: onDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Shop now',
                          style: AppTypography.bodyTextSmallBold.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three quiet reassurances under the carousel.
class _TrustStrip extends StatelessWidget {
  final String storeName;

  const _TrustStrip({required this.storeName});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Row(
        children: [
          item(Icons.verified_user_outlined, 'Secure\ncheckout'),
          item(Icons.local_shipping_outlined, 'Doorstep\ndelivery'),
          item(Icons.track_changes_rounded, 'Track every\norder'),
        ],
      ),
    );
  }
}

// ── All products ───────────────────────────────────────────────────────

class _AllProductsSlivers extends StatelessWidget {
  const _AllProductsSlivers();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreProductsCubit, StoreProductsState>(
      builder: (context, state) {
        final cubit = context.read<StoreProductsCubit>();
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All products', style: AppTypography.h6Bold),
                          if (state.loaded)
                            Text(
                              '${state.total} item${state.total == 1 ? '' : 's'}',
                              style: AppTypography.bodyTextSmallMedium.copyWith(
                                color: AppColors.mutedTextPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _SortButton(
                      sort: state.query.sort,
                      onTap: () async {
                        final sort = await showStoreSortSheet(
                          context,
                          state.query.sort,
                        );
                        if (sort != null) cubit.setSort(sort);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (state.loading && state.items.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: storeProductGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const StoreProductTileSkeleton(),
                    childCount: 4,
                  ),
                ),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverToBoxAdapter(
                child: StoreErrorView(
                  message: state.error!,
                  onRetry: cubit.refresh,
                ),
              )
            else if (state.loaded && state.items.isEmpty)
              const SliverToBoxAdapter(
                child: StoreEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing on the shelves yet',
                  message: 'New products will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: storeProductGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => StoreProductTile(product: state.items[i]),
                    childCount: state.items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: state.loadingMore
                  ? const StoreLoadMoreIndicator()
                  : SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        );
      },
    );
  }
}

class _SortButton extends StatelessWidget {
  final StoreSort sort;
  final VoidCallback onTap;

  const _SortButton({required this.sort, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.dividerLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(sort.label, style: AppTypography.bodyTextSmallSemiBold),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: StoreSkeletonBox(width: 56, height: 56, radius: 28),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const StoreSkeletonBox(height: 180, radius: 20),
            const SizedBox(height: 24),
            const StoreSkeletonBox(width: 140, height: 18),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: StoreSkeletonBox(height: 220, radius: 16)),
                SizedBox(width: 12),
                Expanded(child: StoreSkeletonBox(height: 220, radius: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
