import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/star_rating.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/domain/usecases/store_order_usecases.dart';
import 'package:nexora/features/store/presentation/bloc/store_order_detail_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';
import 'package:nexora/features/transaction/presentation/widgets/transaction_list.dart';

/// Order detail (O2) with tracking, timeline and the learner's actions:
/// cancel (O3), "I received it" (O4) and rate an item (O5). Each button
/// shows only when the server says it may.
class StoreOrderDetailPage extends StatelessWidget {
  final String orderNo;

  const StoreOrderDetailPage({super.key, required this.orderNo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoreOrderDetailCubit(
        getOrderUseCase: sl<GetStoreOrderUseCase>(),
        cancelOrderUseCase: sl<CancelStoreOrderUseCase>(),
        confirmReceivedUseCase: sl<ConfirmStoreOrderReceivedUseCase>(),
        reviewItemUseCase: sl<ReviewStoreItemUseCase>(),
        orderNo: orderNo,
      )..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreOrderDetailCubit, StoreOrderDetailState>(
      builder: (context, state) {
        final cubit = context.read<StoreOrderDetailCubit>();
        final order = state.order;
        return Scaffold(
          backgroundColor: AppColors.scaffoldLight,
          appBar: CustomAppBar(title: order?.orderNo ?? 'Order details'),
          body: order == null
              ? (state.error != null
                    ? StoreErrorView(message: state.error!, onRetry: cubit.load)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          StoreSkeletonBox(height: 150, radius: 16),
                          SizedBox(height: 12),
                          StoreSkeletonBox(height: 120, radius: 16),
                          SizedBox(height: 12),
                          StoreSkeletonBox(height: 200, radius: 16),
                        ],
                      ))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => cubit.load(silent: true),
                  child: _OrderBody(order: order, acting: state.acting),
                ),
          bottomNavigationBar:
              order == null || !(order.canCancel || order.canConfirmReceived)
              ? null
              : _ActionBar(order: order, acting: state.acting),
        );
      },
    );
  }
}

class _OrderBody extends StatelessWidget {
  final StoreOrderDetail order;
  final bool acting;

  const _OrderBody({required this.order, required this.acting});

  @override
  Widget build(BuildContext context) {
    final o = order;
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        _StatusHero(order: o),
        if (o.tracking != null) _TrackingPanel(tracking: o.tracking!),
        _ItemsPanel(order: o, acting: acting),
        if (o.shipTo != null) _ShipToPanel(shipTo: o.shipTo!),
        if (o.payment != null) _PaymentPanel(order: o),
        if (o.timeline.isNotEmpty) _TimelinePanel(events: o.timeline),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Text(
            [
              if (o.sellerName != null) 'Sold by ${o.sellerName}',
              if (o.placedAt != null)
                'Placed on ${StoreFormat.dateTime(o.placedAt!)}',
            ].join('  ·  '),
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextXtraSmallMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status ─────────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  final StoreOrderDetail order;

  const _StatusHero({required this.order});

  static const _steps = ['placed', 'confirmed', 'shipped', 'delivered'];
  static const _labels = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final o = order;
    final (color, icon) = storeStatusTone(o.status);
    final String headline;
    if (o.status.isDelivered && o.deliveredAt != null) {
      headline = 'Delivered on ${StoreFormat.date(o.deliveredAt!)}';
    } else if (o.status.isCancelled) {
      headline = 'This order was cancelled';
    } else {
      final window = StoreFormat.dateRange(
        o.expectedDeliveryFrom,
        o.expectedDeliveryTo,
      );
      headline = window != null ? 'Arriving $window' : o.status.label;
    }
    final current = _steps.indexOf(o.status.key);

    return StorePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.status.label,
                      style: AppTypography.bodyTextSmallBold.copyWith(
                        color: color,
                      ),
                    ),
                    Text(headline, style: AppTypography.bodyTextLargeBold),
                  ],
                ),
              ),
            ],
          ),
          if (o.status.isCancelled)
            _CancelledNote(order: o)
          else if (current >= 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  _StepDot(
                    label: _labels[i],
                    done: i <= current,
                    current: i == current,
                  ),
                  if (i < _steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: i < current
                              ? AppColors.success
                              : AppColors.grey200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool current;

  const _StepDot({
    required this.label,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: current ? 22 : 18,
          height: current ? 22 : 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.success : AppColors.white,
            border: Border.all(
              color: done ? AppColors.success : AppColors.grey200,
              width: 2,
            ),
            boxShadow: current
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: AppColors.alwaysWhite,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodyTextXtraSmallBold.copyWith(
            color: done ? AppColors.textPrimary : AppColors.mutedTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _CancelledNote extends StatelessWidget {
  final StoreOrderDetail order;

  const _CancelledNote({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final refund = o.refunds.isNotEmpty ? o.refunds.last : null;
    final refundText = refund == null
        ? null
        : '${StoreFormat.money(refund.amount)} refund · '
              '${_refundLabel(refund.status)}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (o.cancelReason != null)
            Text(
              'Reason: ${o.cancelReason}',
              style: AppTypography.bodyTextSmallSemiBold,
            ),
          if (o.cancelledBy != null)
            Text(
              'Cancelled by ${o.cancelledBy}',
              style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          if (refundText != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.currency_exchange_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    refundText,
                    style: AppTypography.bodyTextSmallBold.copyWith(
                      color: AppColors.successDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _refundLabel(String status) {
    final r = StoreRefundState.fromWire(status);
    return r == StoreRefundState.none ? _capitalize(status) : r.label;
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ── Tracking ───────────────────────────────────────────────────────────

class _TrackingPanel extends StatelessWidget {
  final StoreTracking tracking;

  const _TrackingPanel({required this.tracking});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(tracking.trackingUrl ?? '');
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      CustomSnackbar.error(
        context,
        title: 'Couldn’t open tracking',
        message: 'Copy the tracking number and check the courier’s site.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tracking;
    return StorePanel(
      title: 'Track your package',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.warningDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.courier ?? 'Courier',
                      style: AppTypography.bodyTextBold,
                    ),
                    if (t.trackingNumber != null)
                      Text(
                        t.trackingNumber!,
                        style: AppTypography.bodyTextSmallMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (t.trackingNumber != null)
                IconButton(
                  tooltip: 'Copy tracking number',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: t.trackingNumber!));
                    CustomSnackbar.success(
                      context,
                      title: 'Copied',
                      message: 'Tracking number copied.',
                    );
                  },
                  icon: Icon(Icons.copy_rounded, color: AppColors.primary),
                ),
            ],
          ),
          if (t.trackingUrl != null) ...[
            const SizedBox(height: 12),
            StorePrimaryButton(
              label: 'Track shipment',
              icon: Icons.open_in_new_rounded,
              height: 46,
              onPressed: () => _open(context),
            ),
            if (t.trackingHost != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'opens ${t.trackingHost}',
                  textAlign: TextAlign.center,
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
}

// ── Items ──────────────────────────────────────────────────────────────

class _ItemsPanel extends StatelessWidget {
  final StoreOrderDetail order;
  final bool acting;

  const _ItemsPanel({required this.order, required this.acting});

  Future<void> _rate(BuildContext context, StoreOrderItem item) async {
    final cubit = context.read<StoreOrderDetailCubit>();
    final input = await showStoreSheet<(int, String)>(
      context,
      title: 'Rate this product',
      builder: (_) => _ReviewSheet(item: item),
    );
    if (input == null || !context.mounted) return;
    final (ok, message) = await cubit.review(
      item.itemId,
      rating: input.$1,
      comment: input.$2,
    );
    if (!context.mounted) return;
    if (ok) {
      CustomSnackbar.success(
        context,
        title: 'Thanks!',
        message: input.$2.trim().isEmpty
            ? 'Your rating has been added.'
            : 'Your review will appear once it’s checked.',
      );
    } else {
      CustomSnackbar.error(context, title: 'Not submitted', message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = order.items;
    return StorePanel(
      title: 'Items',
      trailing: Text(
        '${items.length} item${items.length == 1 ? '' : 's'}',
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.mutedTextPrimary,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 24, color: AppColors.dividerLight),
            _ItemRow(
              item: items[i],
              acting: acting,
              onRate: () => _rate(context, items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final StoreOrderItem item;
  final bool acting;
  final VoidCallback onRate;

  const _ItemRow({
    required this.item,
    required this.acting,
    required this.onRate,
  });

  /// "Warranty until 10 Oct 2027" once delivered, "12-month warranty" before.
  static String _cover(StoreCover c, String kind) {
    final until = c.validUntil;
    return until != null
        ? '${_capitalize(kind)} until ${StoreFormat.date(until)}'
        : '${StoreFormat.coverLength(c.months)} $kind';
  }

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push(
            '${AppRoutes.storeProduct}?id=${Uri.encodeComponent(it.productId)}',
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomNetworkImage(
                  url: it.imageUrl,
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
                      it.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextSemiBold.copyWith(
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Qty ${it.qty} × ${StoreFormat.money(it.unitPrice)}',
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                StoreFormat.money(it.lineTotal),
                style: AppTypography.bodyTextBold,
              ),
            ],
          ),
        ),
        if (it.warranty != null || it.guarantee != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (it.warranty != null)
                _CoverPill(
                  text: _cover(it.warranty!, 'warranty'),
                  icon: Icons.build_circle_outlined,
                  color: AppColors.info,
                ),
              if (it.guarantee != null)
                _CoverPill(
                  text: _cover(it.guarantee!, 'guarantee'),
                  icon: Icons.verified_outlined,
                  color: AppColors.success,
                ),
            ],
          ),
        ],
        if (it.myReview != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Your rating',
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              StarRating(
                rating: it.myReview!.rating.toDouble(),
                size: 16,
                color: AppColors.ratingColor,
                emptyColor: AppColors.grey300,
              ),
            ],
          ),
        ] else if (it.canReview) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: acting ? null : onRate,
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('Rate product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ratingColor,
                side: BorderSide(
                  color: AppColors.ratingColor.withValues(alpha: 0.6),
                ),
                textStyle: AppTypography.bodyTextSmallBold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CoverPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _CoverPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Ship to / payment / timeline ───────────────────────────────────────

class _ShipToPanel extends StatelessWidget {
  final StoreShipTo shipTo;

  const _ShipToPanel({required this.shipTo});

  @override
  Widget build(BuildContext context) {
    final s = shipTo;
    final secondary = AppTypography.bodyTextMedium.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    return StorePanel(
      title: 'Shipping to',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.fullName, style: AppTypography.bodyTextLargeBold),
          const SizedBox(height: 4),
          Text(s.streetLine, style: secondary),
          Text(s.cityLine, style: secondary),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 14, color: AppColors.grey400),
              const SizedBox(width: 5),
              Text(s.phone, style: AppTypography.bodyTextSmallSemiBold),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  final StoreOrderDetail order;

  const _PaymentPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = order.payment!;
    final tax = p.tax;
    return StorePanel(
      title: 'Payment summary',
      child: Column(
        children: [
          StoreBillRow(
            label: 'Items (incl. GST)',
            value: StoreFormat.money(p.itemsTotal),
          ),
          StoreBillRow(
            label: 'Delivery',
            value: p.deliveryCharge == 0
                ? 'FREE'
                : StoreFormat.money(p.deliveryCharge),
            valueColor: p.deliveryCharge == 0 ? AppColors.success : null,
          ),
          if (p.couponDiscount > 0)
            StoreBillRow(
              label: 'Coupon discount',
              value: '− ${StoreFormat.money(p.couponDiscount)}',
              valueColor: AppColors.success,
            ),
          if (tax.sellerGstRegistered)
            StoreBillRow(
              label: 'GST included',
              hint: tax.isInter ? 'incl. IGST' : 'incl. CGST + SGST',
              value: StoreFormat.money(tax.total),
              valueColor: AppColors.textSecondary,
            ),
          if (p.gatewayFee > 0)
            StoreBillRow(
              label: 'Payment gateway fee',
              value: StoreFormat.money(p.gatewayFee),
            ),
          const StoreDashedDivider(),
          StoreBillRow(
            label: 'Amount paid',
            value: StoreFormat.money(p.paid),
            emphasis: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 15,
                color: AppColors.mutedTextPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.isTaxInvoice
                      ? 'Tax invoice'
                            '${p.sellerGstin != null ? ' · GSTIN ${p.sellerGstin}' : ''}'
                      : 'Bill of supply',
                  style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Same document as the row in Transaction History. The invoice is
          // issued at dispatch; before that (or after a cancellation) the
          // same download is a payment receipt.
          StoreOutlinedButton(
            label: _invoiced ? 'Download invoice' : 'Download receipt',
            icon: Icons.download_rounded,
            height: 44,
            onPressed: () => openStoreInvoice(context, order.orderNo),
          ),
        ],
      ),
    );
  }

  bool get _invoiced =>
      order.status.isShipped ||
      order.status.isDelivered ||
      order.deliveredAt != null;
}

class _TimelinePanel extends StatelessWidget {
  final List<StoreTimelineEvent> events;

  const _TimelinePanel({required this.events});

  @override
  Widget build(BuildContext context) {
    return StorePanel(
      title: 'Order history',
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == events.length - 1
                                ? AppColors.primaryFill
                                : AppColors.white,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        if (i < events.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < events.length - 1 ? 16 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            events[i].label,
                            style: AppTypography.bodyTextSemiBold,
                          ),
                          if (events[i].note != null)
                            Text(
                              events[i].note!,
                              style: AppTypography.bodyTextSmallMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (events[i].at != null)
                            Text(
                              StoreFormat.dateTime(events[i].at!),
                              style: AppTypography.bodyTextXtraSmallMedium
                                  .copyWith(color: AppColors.mutedTextPrimary),
                            ),
                        ],
                      ),
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

// ── Actions ────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final StoreOrderDetail order;
  final bool acting;

  const _ActionBar({required this.order, required this.acting});

  Future<void> _cancel(BuildContext context) async {
    final cubit = context.read<StoreOrderDetailCubit>();
    final reason = await showStoreSheet<String>(
      context,
      title: 'Cancel order',
      builder: (_) => const _CancelSheet(),
    );
    if (reason == null || !context.mounted) return;
    final (ok, message) = await cubit.cancel(reason: reason);
    if (!context.mounted) return;
    ok
        ? CustomSnackbar.success(
            context,
            title: 'Order cancelled',
            message: message,
          )
        : CustomSnackbar.error(
            context,
            title: 'Not cancelled',
            message: message,
          );
  }

  Future<void> _received(BuildContext context) async {
    final cubit = context.read<StoreOrderDetailCubit>();
    final yes = await showStoreConfirm(
      context,
      title: 'Got your order?',
      message:
          'Confirm only once the package is in your hands. This starts any '
          'warranty and lets you rate the products.',
      confirmLabel: 'Yes, received',
    );
    if (!yes || !context.mounted) return;
    final (ok, message) = await cubit.confirmReceived();
    if (!context.mounted) return;
    ok
        ? CustomSnackbar.success(context, title: 'Delivered', message: message)
        : CustomSnackbar.error(context, title: 'Not updated', message: message);
  }

  @override
  Widget build(BuildContext context) {
    return StoreBottomBar(
      child: Row(
        children: [
          if (order.canCancel)
            Expanded(
              child: StoreOutlinedButton(
                label: 'Cancel order',
                icon: Icons.close_rounded,
                color: AppColors.error,
                loading: acting && !order.canConfirmReceived,
                onPressed: acting ? null : () => _cancel(context),
              ),
            ),
          if (order.canCancel && order.canConfirmReceived)
            const SizedBox(width: 12),
          if (order.canConfirmReceived)
            Expanded(
              child: StorePrimaryButton(
                label: 'I received it',
                icon: Icons.inventory_rounded,
                loading: acting,
                onPressed: () => _received(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  static const _reasons = [
    'Ordered by mistake',
    'Found it cheaper elsewhere',
    'Delivery is taking too long',
    'Need to change the address',
    'Other',
  ];
  String? _picked;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _picked == 'Other';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The full amount is refunded automatically.',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _picked,
            onChanged: (v) => setState(() => _picked = v),
            child: Column(
              children: [
                for (final r in _reasons)
                  RadioListTile<String>(
                    value: r,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r, style: AppTypography.bodyTextLargeMedium),
                  ),
              ],
            ),
          ),
          if (isOther)
            TextField(
              controller: _other,
              maxLength: 300,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Tell us a little more (optional)',
                filled: true,
                fillColor: AppColors.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          const SizedBox(height: 12),
          StorePrimaryButton(
            label: 'Cancel order',
            height: 48,
            onPressed: _picked == null
                ? null
                : () => Navigator.of(context).pop(
                    isOther
                        ? (_other.text.trim().isEmpty
                              ? 'Other'
                              : _other.text.trim())
                        : _picked!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final StoreOrderItem item;

  const _ReviewSheet({required this.item});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();

  static const _words = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CustomNetworkImage(
                url: widget.item.imageUrl,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextSemiBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var s = 1; s <= 5; s++)
                IconButton(
                  iconSize: 40,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = s);
                  },
                  icon: Icon(
                    s <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: s <= _rating
                        ? AppColors.ratingColor
                        : AppColors.grey300,
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 22,
            child: Text(
              _words[_rating],
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextBold.copyWith(
                color: AppColors.ratingColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _comment,
            maxLength: 1000,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What did you like or dislike? (optional)',
              filled: true,
              fillColor: AppColors.grey100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          StorePrimaryButton(
            label: 'Submit',
            height: 48,
            onPressed: _rating == 0
                ? null
                : () => Navigator.of(context).pop((_rating, _comment.text)),
          ),
        ],
      ),
    );
  }
}
