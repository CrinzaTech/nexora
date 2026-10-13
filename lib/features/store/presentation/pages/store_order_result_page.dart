import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// What happened to a payment, and where to go next.
enum StoreOrderResultKind {
  /// P3 said `paid: true` — the order is placed.
  paid,

  /// Razorpay has not captured it yet. Never offers to pay again.
  pending,

  /// The order expired before the money arrived; refund is automatic.
  refunding;

  static StoreOrderResultKind fromWire(String? v) =>
      values.firstWhere((k) => k.name == v, orElse: () => pending);
}

class StoreOrderResultPage extends StatefulWidget {
  final StoreOrderResultKind kind;
  final String orderNo;
  final String? message;

  const StoreOrderResultPage({
    super.key,
    required this.kind,
    required this.orderNo,
    this.message,
  });

  @override
  State<StoreOrderResultPage> createState() => _StoreOrderResultPageState();
}

class _StoreOrderResultPageState extends State<StoreOrderResultPage>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    if (widget.kind == StoreOrderResultKind.paid) HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _continueShopping() {
    var found = false;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name == 'store') found = true;
      return found || route.isFirst;
    });
    if (!found) context.push(AppRoutes.store);
  }

  void _viewOrder() => context.pushReplacement(
    '${AppRoutes.storeOrder}?orderNo=${Uri.encodeComponent(widget.orderNo)}',
  );

  void _viewOrders() => context.pushReplacement(AppRoutes.storeOrders);

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, body) = switch (widget.kind) {
      StoreOrderResultKind.paid => (
        AppColors.success,
        Icons.check_rounded,
        'Order placed!',
        'Thank you! The seller will confirm and pack your order soon. '
            'We’ll keep you posted at every step.',
      ),
      StoreOrderResultKind.pending => (
        AppColors.warning,
        Icons.hourglass_top_rounded,
        'Confirming your payment',
        widget.message ??
            'Your payment is being confirmed. Check My orders in a minute.',
      ),
      StoreOrderResultKind.refunding => (
        AppColors.info,
        Icons.currency_exchange_rounded,
        'Your money is on its way back',
        widget.message ??
            'This order expired before the payment arrived. The refund is '
                'automatic.',
      ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continueShopping();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _anim,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          size: 48,
                          color: AppColors.alwaysWhite,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _anim,
                    curve: const Interval(0.3, 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.h4Bold,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTextLargeMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          border: Border.all(color: AppColors.dividerLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order ${widget.orderNo}',
                              style: AppTypography.bodyTextBold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                if (widget.kind == StoreOrderResultKind.paid)
                  StorePrimaryButton(
                    label: 'View order',
                    icon: Icons.local_shipping_outlined,
                    onPressed: _viewOrder,
                  )
                else
                  StorePrimaryButton(
                    label: 'Go to My orders',
                    icon: Icons.receipt_long_outlined,
                    onPressed: _viewOrders,
                  ),
                const SizedBox(height: 12),
                StoreOutlinedButton(
                  label: 'Continue shopping',
                  onPressed: _continueShopping,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
