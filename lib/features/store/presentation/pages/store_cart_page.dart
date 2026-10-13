import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/store/data/models/store_cart_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// The cart (K1). Prices and stock are live, so it re-reads on every
/// visit; every change redraws from the server's answer.
class StoreCartPage extends StatefulWidget {
  const StoreCartPage({super.key});

  @override
  State<StoreCartPage> createState() => _StoreCartPageState();
}

class _StoreCartPageState extends State<StoreCartPage> {
  @override
  void initState() {
    super.initState();
    context.read<StoreCartCubit>().load(silent: true);
  }

  Future<void> _run(Future<String?> action) async {
    final error = await action;
    if (error != null && mounted) {
      CustomSnackbar.error(context, title: 'Cart not updated', message: error);
    }
  }

  Future<void> _clear() async {
    final ok = await showStoreConfirm(
      context,
      title: 'Empty your cart?',
      message: 'Every item will be removed.',
      confirmLabel: 'Empty cart',
      destructive: true,
    );
    if (ok && mounted) await _run(context.read<StoreCartCubit>().clear());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCartCubit, StoreCartState>(
      builder: (context, state) {
        final cart = state.cart;
        final hasItems = cart != null && !cart.isEmpty;
        return Scaffold(
          backgroundColor: AppColors.scaffoldLight,
          appBar: CustomAppBar(
            title: hasItems ? 'My cart (${cart.items.length})' : 'My cart',
            actions: [
              if (hasItems)
                TextButton(
                  onPressed: state.isBusy('*') ? null : _clear,
                  child: Text(
                    'Clear',
                    style: AppTypography.bodyTextSemiBold.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: _body(context, state),
          bottomNavigationBar: hasItems ? _checkoutBar(context, cart) : null,
        );
      },
    );
  }

  Widget _body(BuildContext context, StoreCartState state) {
    final cubit = context.read<StoreCartCubit>();
    final cart = state.cart;
    if (cart == null) {
      if (state.error != null) {
        return StoreErrorView(message: state.error!, onRetry: cubit.load);
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: StoreSkeletonBox(height: 120, radius: 16),
          ),
        ),
      );
    }
    if (cart.isEmpty) {
      return StoreEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Your cart is empty',
        message: 'Books, kits and more from your academy are waiting.',
        actionLabel: 'Start shopping',
        onAction: () => _backToStore(context),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => cubit.load(silent: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          if (!cart.canCheckout)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: const StoreIssueText(
                  message:
                      'Some items need your attention before you can check out.',
                ),
              ),
            ),
          for (final line in cart.items)
            _CartLineCard(
              line: line,
              busy: state.isBusy(line.productId),
              onQty: (q) => _run(cubit.setQty(line.productId, q)),
              onRemove: () => _run(cubit.remove(line.productId)),
            ),
          StorePanel(
            title: 'Price details',
            child: Column(
              children: [
                StoreBillRow(
                  label:
                      'Price (${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'})',
                  value: StoreFormat.money(cart.mrpTotal),
                ),
                if (cart.savings > 0)
                  StoreBillRow(
                    label: 'Discount',
                    value: '− ${StoreFormat.money(cart.savings)}',
                    valueColor: AppColors.success,
                  ),
                StoreBillRow(
                  label: 'Delivery',
                  value: cart.deliveryCharge == 0
                      ? 'FREE'
                      : StoreFormat.money(cart.deliveryCharge),
                  valueColor: cart.deliveryCharge == 0
                      ? AppColors.success
                      : null,
                  hint: cart.deliveryCharge == 0
                      ? null
                      : 'Charged once per order',
                ),
                const StoreDashedDivider(),
                StoreBillRow(
                  label: 'Estimated total',
                  value: StoreFormat.money(cart.estimatedTotal),
                  emphasis: true,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'GST included. Final amount is shown at checkout.',
                    style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ),
                if (cart.savings > 0) ...[
                  const SizedBox(height: 12),
                  StoreSavingsBanner(savings: cart.savings),
                ],
              ],
            ),
          ),
          const _SecureNote(),
        ],
      ),
    );
  }

  Widget _checkoutBar(BuildContext context, StoreCart cart) {
    return StoreBottomBar(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                StoreFormat.money(cart.estimatedTotal),
                style: AppTypography.h6Bold,
              ),
              Text(
                cart.savings > 0
                    ? 'Saving ${StoreFormat.money(cart.savings)}'
                    : 'Estimated total',
                style: AppTypography.bodyTextXtraSmallBold.copyWith(
                  color: cart.savings > 0
                      ? AppColors.success
                      : AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StorePrimaryButton(
              label: 'Checkout',
              icon: Icons.lock_outline_rounded,
              onPressed: cart.canCheckout
                  ? () => context.push(AppRoutes.storeCheckout)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _backToStore(BuildContext context) {
    final nav = Navigator.of(context);
    var found = false;
    nav.popUntil((route) {
      if (route.settings.name == 'store') found = true;
      return found || route.isFirst;
    });
    if (!found) context.push(AppRoutes.store);
  }
}

class _CartLineCard extends StatelessWidget {
  final StoreCartLine line;
  final bool busy;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  const _CartLineCard({
    required this.line,
    required this.busy,
    required this.onQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final issue = line.issue;
    final dimmed = !line.isAvailable;
    return StorePanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push(
                  '${AppRoutes.storeProduct}'
                  '?id=${Uri.encodeComponent(line.productId)}',
                ),
                child: Opacity(
                  opacity: dimmed ? 0.5 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.grey50,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: CustomNetworkImage(
                      url: line.imageUrl,
                      width: 84,
                      height: 84,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            line.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextSemiBold.copyWith(
                              height: 1.3,
                            ),
                          ),
                        ),
                        InkResponse(
                          onTap: busy ? null : onRemove,
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.grey400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          StoreFormat.money(line.unitPrice),
                          style: AppTypography.bodyTextLargeBold,
                        ),
                        if (line.unitMrp > line.unitPrice)
                          Text(
                            StoreFormat.money(line.unitMrp),
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.mutedTextPrimary,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.mutedTextPrimary,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'per item',
                      style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (issue != null) ...[
            const SizedBox(height: 10),
            StoreIssueText(message: issue.message),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (line.isAvailable && line.maxQty > 0)
                StoreQtyStepper(
                  qty: line.qty,
                  max: line.maxQty < line.qty ? line.qty : line.maxQty,
                  dense: true,
                  busy: busy,
                  onChanged: onQty,
                  onRemove: onRemove,
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (issue != null && issue.canReduce && line.maxQty > 0)
                _FixButton(
                  label: 'Change to ${line.maxQty}',
                  onTap: busy ? null : () => onQty(line.maxQty),
                )
              else if (issue != null)
                _FixButton(label: 'Remove', onTap: busy ? null : onRemove)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                    Text(
                      StoreFormat.money(line.lineTotal),
                      style: AppTypography.bodyTextLargeBold,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _FixButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.errorBackground,
        foregroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(
        label,
        style: AppTypography.bodyTextSmallBold.copyWith(color: AppColors.error),
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.mutedTextPrimary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Safe and secure payments via Razorpay',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
