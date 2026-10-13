import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/branding_config.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/models/store_checkout_model.dart';
import 'package:nexora/features/store/domain/usecases/store_address_usecases.dart';
import 'package:nexora/features/store/domain/usecases/store_checkout_usecases.dart';
import 'package:nexora/features/store/presentation/bloc/store_cart_cubit.dart';
import 'package:nexora/features/store/presentation/bloc/store_checkout_cubit.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_address_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Checkout: address → quote (P1) → Pay (P2) → Razorpay → verify (P3).
class StoreCheckoutPage extends StatelessWidget {
  final StoreCheckoutSource source;

  const StoreCheckoutPage({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoreCheckoutCubit(
        source: source,
        getAddressesUseCase: sl<GetStoreAddressesUseCase>(),
        getQuoteUseCase: sl<GetStoreQuoteUseCase>(),
        placeOrderUseCase: sl<PlaceStoreOrderUseCase>(),
        verifyPaymentUseCase: sl<VerifyStorePaymentUseCase>(),
      )..start(),
      child: const _CheckoutView(),
    );
  }
}

/// Stateful because Razorpay reports through listeners that must be
/// registered before the first tap and cleared on dispose — left attached,
/// a second sheet ends up with two handlers verifying one payment.
class _CheckoutView extends StatefulWidget {
  const _CheckoutView();

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Razorpay ───────────────────────────────────────────────────────

  /// Not a purchase yet: P3 (or the webhook) is what places the order.
  void _onPaymentSuccess(PaymentSuccessResponse r) {
    if (!mounted) return;
    context.read<StoreCheckoutCubit>().verify(
      razorpayOrderId: r.orderId ?? '',
      razorpayPaymentId: r.paymentId ?? '',
      razorpaySignature: r.signature ?? '',
    );
  }

  void _onPaymentError(PaymentFailureResponse r) {
    if (!mounted) return;
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      CustomSnackbar.info(
        context,
        title: 'Payment cancelled',
        message: 'Nothing was charged. Tap Pay to try again.',
      );
      return;
    }
    context.read<StoreCheckoutCubit>().paymentFailed(
      'Payment failed. Nothing was charged, so you can try again.',
    );
  }

  void _openRazorpay(StorePlacedOrder o) {
    _razorpay.open(<String, dynamic>{
      'key': o.keyId,
      'order_id': o.razorpayOrderId,
      // PAISE. `amountRupees` is for the button label only.
      'amount': o.amountPaise,
      'currency': o.currency,
      'name': currentBranding.appName,
      'description': o.description,
      'send_sms_hash': false,
      'retry': {'enabled': false},
      'modal': {'confirm_close': true, 'handleback': true, 'escape': false},
      'prefill': <String, dynamic>{
        'name': ?o.prefillName,
        'email': ?o.prefillEmail,
        'contact': ?o.prefillContact,
      },
    });
  }

  // ── Events ─────────────────────────────────────────────────────────

  void _onEvent(BuildContext context, StoreCheckoutState state) {
    final event = state.event;
    if (event == null) return;
    final cart = context.read<StoreCartCubit>();
    String result(String kind, String orderNo, [String? message]) =>
        '${AppRoutes.storeOrderResult}?kind=$kind'
        '&orderNo=${Uri.encodeComponent(orderNo)}'
        '${message == null ? '' : '&message=${Uri.encodeComponent(message)}'}';

    switch (event) {
      case StoreCheckoutOpenPayment(:final order):
        _openRazorpay(order);
      case StoreCheckoutPaid(:final orderNo):
        cart.afterPurchase();
        context.pushReplacement(result('paid', orderNo));
      case StoreCheckoutPending(:final message, :final orderNo):
        cart.afterPurchase();
        context.pushReplacement(result('pending', orderNo, message));
      case StoreCheckoutRefunding(:final message, :final orderNo):
        context.pushReplacement(result('refunding', orderNo, message));
      case StoreCheckoutFailed(:final message):
        CustomSnackbar.error(
          context,
          title: 'Payment failed',
          message: message,
        );
      case StoreCheckoutRefused(:final message):
        CustomSnackbar.error(
          context,
          title: 'Couldn’t place order',
          message: message,
        );
        if (!state.source.isBuyNow) cart.load(silent: true);
      case StoreCheckoutError(:final message):
        CustomSnackbar.error(
          context,
          title: 'Please try again',
          message: message,
        );
    }
  }

  // ── Address ────────────────────────────────────────────────────────

  Future<void> _changeAddress(StoreCheckoutState state) async {
    final cubit = context.read<StoreCheckoutCubit>();
    final picked = await context.push<StoreAddress>(
      '${AppRoutes.storeAddresses}?select=1'
      '${state.address == null ? '' : '&selectedId=${state.address!.id}'}',
    );
    if (!mounted) return;
    // Edits or deletions made in the book apply whether or not one was picked.
    await cubit.addressesChanged(picked: picked);
  }

  Future<void> _addAddress() async {
    final cubit = context.read<StoreCheckoutCubit>();
    final saved = await context.push<StoreAddress>(AppRoutes.storeAddressForm);
    if (!mounted || saved == null) return;
    await cubit.addressesChanged(picked: saved);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StoreCheckoutCubit, StoreCheckoutState>(
      listenWhen: (a, b) => a.eventSeq != b.eventSeq,
      listener: _onEvent,
      builder: (context, state) {
        return PopScope(
          // Leaving mid-verify would strand the answer; everything else is
          // safe — an unpaid order releases its stock after 30 minutes.
          canPop: !state.verifying,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: AppColors.scaffoldLight,
                appBar: const CustomAppBar(title: 'Checkout'),
                body: _body(state),
                bottomNavigationBar: _payBar(state),
              ),
              if (state.verifying) const _VerifyingOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _body(StoreCheckoutState state) {
    final cubit = context.read<StoreCheckoutCubit>();
    if (state.loadingAddresses && state.addresses.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          StoreSkeletonBox(height: 120, radius: 16),
          SizedBox(height: 12),
          StoreSkeletonBox(height: 160, radius: 16),
          SizedBox(height: 12),
          StoreSkeletonBox(height: 200, radius: 16),
        ],
      );
    }
    if (state.addressesError != null && state.addresses.isEmpty) {
      return StoreErrorView(
        message: state.addressesError!,
        onRetry: cubit.start,
      );
    }
    final quote = state.quote;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: cubit.refreshQuote,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          const _StepHeader(),
          _addressPanel(state),
          if (state.address != null) ...[
            if (state.quoting && quote == null)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: StoreSkeletonBox(height: 220, radius: 16),
              )
            else if (state.quoteError != null && quote == null)
              StorePanel(
                child: Column(
                  children: [
                    StoreIssueText(message: state.quoteError!),
                    const SizedBox(height: 12),
                    StoreOutlinedButton(
                      label: 'Try again',
                      height: 44,
                      onPressed: cubit.refreshQuote,
                    ),
                  ],
                ),
              )
            else if (quote != null) ...[
              if (!quote.canPlaceOrder) _blockedBanner(quote),
              _itemsPanel(quote, state.quoting),
              _billPanel(quote, state.quoting),
            ],
          ],
          const _TrustFooter(),
        ],
      ),
    );
  }

  Widget _addressPanel(StoreCheckoutState state) {
    final address = state.address;
    if (address == null) {
      return StorePanel(
        title: 'Delivery address',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where should we deliver your order?',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            StorePrimaryButton(
              label: 'Add delivery address',
              icon: Icons.add_location_alt_outlined,
              height: 48,
              onPressed: _addAddress,
            ),
          ],
        ),
      );
    }
    return StorePanel(
      title: 'Deliver to',
      trailing: TextButton(
        onPressed: state.busy || state.finished
            ? null
            : () => _changeAddress(state),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          'Change',
          style: AppTypography.bodyTextSemiBold.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      child: StoreAddressSummary(address: address, showDefault: false),
    );
  }

  Widget _blockedBanner(StoreQuote quote) {
    final reasons = [
      if (quote.blockedReason != null)
        quote.blockedReason!
      else
        for (final line in quote.items)
          if (line.issue != null) '${line.title}: ${line.issue!.message}',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This order can’t be placed yet',
            style: AppTypography.bodyTextBold.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 6),
          if (reasons.isEmpty)
            const StoreIssueText(message: 'Please review the items below.')
          else
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StoreIssueText(message: r),
              ),
        ],
      ),
    );
  }

  Widget _itemsPanel(StoreQuote quote, bool refreshing) {
    final window = StoreFormat.dateRange(
      quote.expectedDeliveryFrom,
      quote.expectedDeliveryTo,
    );
    return StorePanel(
      title: 'Order summary',
      trailing: refreshing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Text(
              '${quote.items.length} item${quote.items.length == 1 ? '' : 's'}',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
      child: Column(
        children: [
          if (window != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expected delivery $window',
                    style: AppTypography.bodyTextSmallBold.copyWith(
                      color: AppColors.infoDark,
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < quote.items.length; i++) ...[
            if (i > 0) Divider(height: 20, color: AppColors.dividerLight),
            _QuoteLineRow(line: quote.items[i]),
          ],
        ],
      ),
    );
  }

  /// The bill exactly as STORE_API.md §7 lays it out.
  Widget _billPanel(StoreQuote quote, bool refreshing) {
    final tax = quote.tax;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: refreshing ? 0.5 : 1,
      child: StorePanel(
        title: 'Bill details',
        child: Column(
          children: [
            StoreBillRow(
              label: 'Items (incl. GST)',
              value: StoreFormat.money(quote.itemsTotal),
            ),
            StoreBillRow(
              label: 'Delivery',
              value: quote.deliveryCharge == 0
                  ? 'FREE'
                  : StoreFormat.money(quote.deliveryCharge),
              valueColor: quote.deliveryCharge == 0 ? AppColors.success : null,
            ),
            if (quote.couponDiscount > 0)
              StoreBillRow(
                label: 'Coupon discount',
                value: '− ${StoreFormat.money(quote.couponDiscount)}',
                valueColor: AppColors.success,
              ),
            if (tax.sellerGstRegistered)
              StoreBillRow(
                label: 'GST included',
                hint: tax.isInter ? 'incl. IGST' : 'incl. CGST + SGST',
                value: StoreFormat.money(tax.total),
                valueColor: AppColors.textSecondary,
              ),
            if (quote.gatewayFee > 0)
              StoreBillRow(
                label: 'Payment gateway fee',
                value: StoreFormat.money(quote.gatewayFee),
              ),
            const StoreDashedDivider(),
            StoreBillRow(
              label: 'Total',
              value: StoreFormat.money(quote.payable),
              emphasis: true,
            ),
            if (quote.savings > 0) ...[
              const SizedBox(height: 10),
              StoreSavingsBanner(savings: quote.savings),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _payBar(StoreCheckoutState state) {
    if (state.address == null) return null;
    final cubit = context.read<StoreCheckoutCubit>();
    final payable = state.payable;
    final label = state.placing
        ? 'Placing order…'
        : payable == null
        ? 'Pay'
        : 'Pay ${StoreFormat.money(payable)}';
    return StoreBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.order != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Order ${state.order!.orderNo} is reserved for you. Please '
                'pay within 30 minutes.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                  color: AppColors.warningDark,
                ),
              ),
            ),
          StorePrimaryButton(
            label: label,
            icon: Icons.lock_rounded,
            loading: state.placing,
            onPressed: state.canPay ? cubit.pay : null,
          ),
        ],
      ),
    );
  }
}

class _QuoteLineRow extends StatelessWidget {
  final StoreQuoteLine line;

  const _QuoteLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomNetworkImage(
                url: line.imageUrl,
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextSemiBold.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty ${line.qty} × ${StoreFormat.money(line.unitPrice)}',
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                  if (line.warranty != null || line.guarantee != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (line.warranty != null)
                            '${StoreFormat.coverLength(line.warranty!.months)} warranty',
                          if (line.guarantee != null)
                            '${StoreFormat.coverLength(line.guarantee!.months)} guarantee',
                        ].join(' · '),
                        style: AppTypography.bodyTextXtraSmallBold.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              StoreFormat.money(line.lineTotal),
              style: AppTypography.bodyTextBold,
            ),
          ],
        ),
        if (line.issue != null) ...[
          const SizedBox(height: 8),
          StoreIssueText(message: line.issue!.message),
        ],
      ],
    );
  }
}

/// Bag → Checkout → Done.
class _StepHeader extends StatelessWidget {
  const _StepHeader();

  @override
  Widget build(BuildContext context) {
    Widget dot(
      String label,
      IconData icon, {
      required bool done,
      bool current = false,
    }) {
      final color = done || current ? AppColors.primary : AppColors.grey300;
      return Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.primaryFill : AppColors.white,
              border: Border.all(color: color, width: 1.6),
            ),
            child: Icon(
              done ? Icons.check_rounded : icon,
              size: 16,
              color: done ? AppColors.onPrimary : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: done || current
                  ? AppColors.textPrimary
                  : AppColors.mutedTextPrimary,
            ),
          ),
        ],
      );
    }

    Widget bar(bool active) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        color: active ? AppColors.primary : AppColors.grey200,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 12, 36, 16),
      child: Row(
        children: [
          dot('Bag', Icons.shopping_bag_outlined, done: true),
          bar(true),
          dot('Checkout', Icons.payments_outlined, done: false, current: true),
          bar(false),
          dot('Done', Icons.celebration_outlined, done: false),
        ],
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.mutedTextPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                '100% secure payments via Razorpay',
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Prices include GST. UPI, cards, net banking and wallets accepted.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextXtraSmallMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyingOverlay extends StatelessWidget {
  const _VerifyingOverlay();

  @override
  Widget build(BuildContext context) {
    // Sits above the Scaffold, so it brings its own Material for text.
    return Positioned.fill(
      child: Material(
        color: AppColors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Confirming your payment',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextLargeBold,
                ),
                const SizedBox(height: 6),
                Text(
                  'Please don’t close the app.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: AppColors.textSecondary,
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
