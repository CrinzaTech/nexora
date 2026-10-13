import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_products_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_product_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// A product grid (C3): a category, a rail's "See all", or search.
class StoreProductsPage extends StatelessWidget {
  final String title;
  final int? categoryId;
  final StoreSort sort;

  /// Opens with the search box focused and the grid empty until the
  /// learner types two letters.
  final bool searchMode;

  const StoreProductsPage({
    super.key,
    required this.title,
    this.categoryId,
    this.sort = StoreSort.newest,
    this.searchMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<StoreProductsCubit>();
        final query = StoreProductQuery(categoryId: categoryId, sort: sort);
        if (searchMode) {
          cubit.search('');
        } else {
          cubit.load(query);
        }
        return cubit;
      },
      child: _ProductsView(title: title, searchMode: searchMode),
    );
  }
}

class _ProductsView extends StatefulWidget {
  final String title;
  final bool searchMode;

  const _ProductsView({required this.title, required this.searchMode});

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    setState(() {}); // the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) context.read<StoreProductsCubit>().search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 30,
            color: AppColors.textPrimary,
          ),
        ),
        titleSpacing: 0,
        title: widget.searchMode
            ? _SearchField(
                controller: _search,
                onChanged: _onSearchChanged,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  context.read<StoreProductsCubit>().search(q);
                },
                onClear: () {
                  _search.clear();
                  _onSearchChanged('');
                },
              )
            : Text(widget.title, style: AppTypography.h6Bold),
        actions: const [StoreCartAction(), SizedBox(width: 6)],
      ),
      body: BlocBuilder<StoreProductsCubit, StoreProductsState>(
        builder: (context, state) {
          final cubit = context.read<StoreProductsCubit>();
          final searchIdle =
              widget.searchMode && (state.query.q?.trim().length ?? 0) < 2;
          return Column(
            children: [
              if (!searchIdle) _FilterBar(state: state),
              Expanded(
                child: searchIdle
                    ? const StoreEmptyState(
                        icon: Icons.search_rounded,
                        title: 'Search the store',
                        message:
                            'Find books, kits and merchandise by name, '
                            'keyword or brand.',
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) =>
                            storeOnScrollEnd(n, cubit.loadMore),
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: cubit.refresh,
                          child: _grid(context, state),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, StoreProductsState state) {
    final cubit = context.read<StoreProductsCubit>();
    final Widget body;
    if (state.loading && state.items.isEmpty) {
      body = SliverGrid(
        gridDelegate: storeProductGridDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (_, _) => const StoreProductTileSkeleton(),
          childCount: 6,
        ),
      );
    } else if (state.error != null && state.items.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: StoreErrorView(message: state.error!, onRetry: cubit.refresh),
      );
    } else if (state.loaded && state.items.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: StoreEmptyState(
          icon: widget.searchMode
              ? Icons.search_off_rounded
              : Icons.inventory_2_outlined,
          title: widget.searchMode ? 'No matches' : 'Nothing here yet',
          message: state.query.hasPriceFilter
              ? 'Try a wider price range.'
              : widget.searchMode
              ? 'Try another word or check the spelling.'
              : 'Products in this section will show up here.',
          actionLabel: state.query.hasPriceFilter ? 'Clear price filter' : null,
          onAction: state.query.hasPriceFilter
              ? () => cubit.setPriceRange(null, null)
              : null,
        ),
      );
    } else {
      body = SliverGrid(
        gridDelegate: storeProductGridDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (_, i) => StoreProductTile(product: state.items[i]),
          childCount: state.items.length,
        ),
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: body,
        ),
        SliverToBoxAdapter(
          child: state.loadingMore
              ? const StoreLoadMoreIndicator()
              : SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: AppTypography.bodyTextLargeMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search the store',
          hintStyle: AppTypography.bodyTextLargeMedium.copyWith(
            color: AppColors.mutedTextPrimary,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.grey400,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

/// Sort and price filter chips plus the result count.
class _FilterBar extends StatelessWidget {
  final StoreProductsState state;

  const _FilterBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StoreProductsCubit>();
    final q = state.query;
    String? priceLabel;
    if (q.minPrice != null && q.maxPrice != null) {
      priceLabel =
          '${StoreFormat.money(q.minPrice!)} to ${StoreFormat.money(q.maxPrice!)}';
    } else if (q.minPrice != null) {
      priceLabel = 'Over ${StoreFormat.money(q.minPrice!)}';
    } else if (q.maxPrice != null) {
      priceLabel = 'Under ${StoreFormat.money(q.maxPrice!)}';
    }
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          _Chip(
            icon: Icons.swap_vert_rounded,
            label: q.sort.label,
            active: q.sort != StoreSort.newest,
            onTap: () async {
              final sort = await showStoreSortSheet(context, q.sort);
              if (sort != null) cubit.setSort(sort);
            },
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.currency_rupee_rounded,
            label: priceLabel ?? 'Price',
            active: priceLabel != null,
            onTap: () async {
              final r = await showStorePriceSheet(
                context,
                min: q.minPrice,
                max: q.maxPrice,
              );
              if (r != null) cubit.setPriceRange(r.min, r.max);
            },
          ),
          const Spacer(),
          if (state.loaded)
            Text(
              '${state.total} result${state.total == 1 ? '' : 's'}',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onPrimary : AppColors.textPrimary;
    return Material(
      color: active ? AppColors.primaryFill : AppColors.grey100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextSmallSemiBold.copyWith(
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
