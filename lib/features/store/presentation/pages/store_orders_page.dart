import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/domain/usecases/store_order_usecases.dart';
import 'package:nexora/features/store/presentation/bloc/store_orders_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// My orders (O1), one tab per group.
class StoreOrdersPage extends StatelessWidget {
  const StoreOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: StoreOrderGroup.values.length,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        appBar: CustomAppBar(
          title: 'My orders',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.mutedTextPrimary,
              labelStyle: AppTypography.bodyTextBold,
              unselectedLabelStyle: AppTypography.bodyTextSemiBold,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.dividerLight,
              tabs: [
                for (final g in StoreOrderGroup.values) Tab(text: g.label),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            for (final g in StoreOrderGroup.values) _OrdersTab(group: g),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  final StoreOrderGroup group;

  const _OrdersTab({required this.group});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  late final StoreOrdersCubit _cubit = StoreOrdersCubit(
    getOrdersUseCase: sl<GetStoreOrdersUseCase>(),
    group: widget.group,
  )..load();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _open(StoreOrderSummary o) async {
    await context.push(
      '${AppRoutes.storeOrder}?orderNo=${Uri.encodeComponent(o.orderNo)}',
    );
    // A cancel or "received" on the detail moves the order between tabs.
    _cubit.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<StoreOrdersCubit, StoreOrdersState>(
      bloc: _cubit,
      builder: (context, state) {
        if (state.loading && !state.loaded) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: StoreSkeletonBox(height: 130, radius: 16),
              ),
            ),
          );
        }
        if (state.error != null && state.items.isEmpty) {
          return StoreErrorView(message: state.error!, onRetry: _cubit.load);
        }
        if (state.items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _cubit.load(silent: true),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: StoreEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _emptyTitle,
                    message: 'Orders you place in the store show up here.',
                  ),
                ),
              ],
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) => storeOnScrollEnd(n, _cubit.loadMore),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _cubit.load(silent: true),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              itemCount: state.items.length + 1,
              itemBuilder: (context, i) {
                if (i == state.items.length) {
                  return state.loadingMore
                      ? const StoreLoadMoreIndicator()
                      : const SizedBox.shrink();
                }
                final o = state.items[i];
                return _OrderCard(order: o, onTap: () => _open(o));
              },
            ),
          ),
        );
      },
    );
  }

  String get _emptyTitle => switch (widget.group) {
    StoreOrderGroup.all => 'No orders yet',
    StoreOrderGroup.active => 'Nothing on the way',
    StoreOrderGroup.delivered => 'No deliveries yet',
    StoreOrderGroup.cancelled => 'No cancelled orders',
  };
}

class _OrderCard extends StatelessWidget {
  final StoreOrderSummary order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final (statusColor, _) = storeStatusTone(o.status);
    String? footnote;
    Color? footColor;
    if (o.status.isCancelled && o.refund != StoreRefundState.none) {
      footnote = o.refund.label;
      footColor = o.refund == StoreRefundState.failed
          ? AppColors.warningDark
          : AppColors.success;
    } else if (o.deliveredAt != null) {
      footnote = 'Delivered on ${StoreFormat.date(o.deliveredAt!)}';
      footColor = AppColors.success;
    } else if (!o.status.isCancelled) {
      final window = StoreFormat.dateRange(
        o.expectedDeliveryFrom,
        o.expectedDeliveryTo,
      );
      if (window != null) {
        footnote = 'Arriving $window';
        footColor = AppColors.info;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: AppDecorations.card(),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              // Status stripe.
              Container(height: 3, color: statusColor.withValues(alpha: 0.8)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StoreStatusChip(status: o.status),
                        const Spacer(),
                        if (o.placedAt != null)
                          Text(
                            StoreFormat.date(o.placedAt!),
                            style: AppTypography.bodyTextXtraSmallMedium
                                .copyWith(color: AppColors.mutedTextPrimary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.grey50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CustomNetworkImage(
                            url: o.firstItemImage,
                            width: 64,
                            height: 64,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.firstItemTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyTextSemiBold.copyWith(
                                  height: 1.3,
                                ),
                              ),
                              if (o.itemCount > 1)
                                Text(
                                  '+${o.itemCount - 1} more',
                                  style: AppTypography.bodyTextSmallBold
                                      .copyWith(color: AppColors.primary),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                o.orderNo,
                                style: AppTypography.bodyTextXtraSmallMedium
                                    .copyWith(
                                      color: AppColors.mutedTextPrimary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.grey300,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.dividerLight),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (footnote != null)
                          Expanded(
                            child: Text(
                              footnote,
                              style: AppTypography.bodyTextSmallBold.copyWith(
                                color: footColor,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        Text(
                          StoreFormat.money(o.payable),
                          style: AppTypography.bodyTextLargeBold,
                        ),
                      ],
                    ),
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
