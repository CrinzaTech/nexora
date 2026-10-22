import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/payment_policy.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/branding_config.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/presentation/bloc/bundle_checkout_cubit.dart';
import 'package:nexora/features/bundles/presentation/bloc/bundle_detail_cubit.dart';
import 'package:nexora/features/bundles/presentation/widgets/bundle_pricing_breakdown.dart';
import 'package:nexora/features/bundles/presentation/widgets/bundle_tile.dart';
import 'package:nexora/features/courses/presentation/widgets/course_cover.dart';
import 'package:nexora/features/store/presentation/store_format.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// The bundle page (B2) and its checkout (P1 → Razorpay → P2).
class BundleDetailPage extends StatelessWidget {
  final int bundleId;

  const BundleDetailPage({super.key, required this.bundleId});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    // A bundle is only ever a purchase, which iOS doesn't offer (see
    // PaymentPolicy). Nothing links here on iOS; a stray deep link gets
    // the neutral line.
    if (!PaymentPolicy.allowsPurchases) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Bundle'),
        body: StoreEmptyState(
          icon: Icons.layers_outlined,
          title: 'Not available',
          message: PaymentPolicy.unavailableMessage,
        ),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<BundleDetailCubit>()..load(bundleId)),
        BlocProvider(create: (_) => sl<BundleCheckoutCubit>()),
      ],
      child: _BundleDetailView(bundleId: bundleId),
    );
  }
}

class _BundleDetailView extends StatelessWidget {
  final int bundleId;

  const _BundleDetailView({required this.bundleId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BundleDetailCubit, BundleDetailState>(
      builder: (context, state) => state.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.scaffoldLight,
          appBar: const CustomAppBar(title: 'Bundle'),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (message, notFound) => Scaffold(
          backgroundColor: AppColors.scaffoldLight,
          appBar: const CustomAppBar(title: 'Bundle'),
          body: notFound
              ? StoreEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Bundle not found',
                  message: message,
                  actionLabel: 'Go back',
                  onAction: () => context.pop(),
                )
              : StoreErrorView(
                  message: message,
                  onRetry: () =>
                      context.read<BundleDetailCubit>().load(bundleId),
                ),
        ),
        loaded: (bundle) => _BundleBody(bundle: bundle),
      ),
    );
  }
}

class _BundleBody extends StatelessWidget {
  final BundleDetail bundle;

  const _BundleBody({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final card = bundle.card;
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: CustomAppBar(title: card.title),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<BundleDetailCubit>().load(
          bundle.bundleId,
          silent: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Summary(bundle: bundle),
            if (bundle.description != null)
              StorePanel(
                title: 'About this bundle',
                child: Text(
                  bundle.description!,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            StorePanel(
              title: card.courseCount == 1
                  ? "What's included (1 course)"
                  : "What's included (${card.courseCount} courses)",
              child: Column(
                children: [
                  for (var i = 0; i < bundle.courses.length; i++) ...[
                    if (i > 0)
                      Divider(height: 24, color: AppColors.dividerLight),
                    _CourseRow(course: bundle.courses[i]),
                  ],
                ],
              ),
            ),
            if (card.canPurchase)
              StorePanel(
                title: 'Price details',
                child: BundlePricingBreakdown(pricing: bundle.pricing),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _CheckoutBar(bundle: bundle),
    );
  }
}

class _Summary extends StatelessWidget {
  final BundleDetail bundle;

  const _Summary({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final card = bundle.card;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CourseCoverImage(
                  url: card.imageUrl,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: BundleCountBadge(count: card.courseCount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(card.title, style: AppTypography.h5Bold.copyWith(height: 1.25)),
          if (card.isPurchased) ...[
            const SizedBox(height: 8),
            const StoreBadge(
              label: 'Purchased',
              color: AppColors.success,
              icon: Icons.verified_rounded,
            ),
          ],
          const SizedBox(height: 12),
          StorePriceRow(
            price: card.price,
            mrp: card.actualPrice,
            discountPercent: card.discountPercent,
            large: true,
          ),
          if (card.hasPersonalPrice) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Your price '),
                  TextSpan(
                    text: StoreFormat.money(card.yourPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (card.ownedCount > 0)
                    TextSpan(
                      text: card.ownedCount == 1
                          ? '  ·  you already own 1 course'
                          : '  ·  you already own ${card.ownedCount} courses',
                      style: TextStyle(color: AppColors.mutedTextPrimary),
                    ),
                ],
              ),
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
          if (card.accessText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppColors.mutedTextPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.accessText,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (card.savings > 0) ...[
            const SizedBox(height: 12),
            StoreSavingsBanner(
              savings: card.savings,
              suffix: 'with this bundle',
            ),
          ],
        ],
      ),
    );
  }
}

/// One course in the bundle, with what buying does for it.
class _CourseRow extends StatelessWidget {
  final BundleCourse course;

  const _CourseRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final note = course.outcome.note;
    return InkWell(
      onTap: () => context.push(
        '${AppRoutes.courseDetail}?courseId=${course.courseId}'
        '&title=${Uri.encodeComponent(course.title)}',
      ),
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CourseCoverImage(
                    url: course.imageUrl,
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    fallbackIconSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accessLine(),
                      style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          StoreFormat.money(course.price),
                          style: AppTypography.bodyTextSmallBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (course.originalPrice > course.price) ...[
                          const SizedBox(width: 6),
                          Text(
                            StoreFormat.money(course.originalPrice),
                            style: AppTypography.bodyTextXtraSmallMedium
                                .copyWith(
                                  color: AppColors.mutedTextPrimary,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.mutedTextPrimary,
                                ),
                          ),
                        ],
                        if (course.isOwned) ...[
                          const Spacer(),
                          const StoreBadge(
                            label: 'Owned',
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            _OutcomeNote(text: note, outcome: course.outcome),
          ],
        ],
      ),
    );
  }

  /// Owned courses say how long the learner's current access runs; the
  /// rest say what the bundle grants.
  String _accessLine() {
    if (!course.isOwned) return course.accessText;
    final expires = course.currentAccessExpiresAt;
    return expires == null
        ? 'Your access: lifetime'
        : 'Your access until ${StoreFormat.date(expires)}';
  }
}

class _OutcomeNote extends StatelessWidget {
  final String text;
  final BundleCourseOutcome outcome;

  const _OutcomeNote({required this.text, required this.outcome});

  @override
  Widget build(BuildContext context) {
    // KEEP_CURRENT is the one the learner should weigh: they pay full
    // price for a course the bundle won't change.
    final warn = outcome == BundleCourseOutcome.keepCurrent;
    final color = warn ? AppColors.warning : AppColors.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warn ? AppColors.warningBackground : AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pinned checkout bar, and the owner of the Razorpay sheet.
///
/// Stateful because Razorpay reports through listeners that must be
/// registered before the first tap and cleared on dispose — left
/// attached, a later sheet verifies one payment twice.
class _CheckoutBar extends StatefulWidget {
  final BundleDetail bundle;

  const _CheckoutBar({required this.bundle});

  @override
  State<_CheckoutBar> createState() => _CheckoutBarState();
}

class _CheckoutBarState extends State<_CheckoutBar> {
  late final Razorpay _razorpay;

  int get _bundleId => widget.bundle.bundleId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  /// **P2 is what unlocks the courses** — never this callback alone.
  void _onPaymentSuccess(PaymentSuccessResponse response) {
    context.read<BundleCheckoutCubit>().verify(
      _bundleId,
      // Byte-for-byte as Razorpay handed them over.
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final cubit = context.read<BundleCheckoutCubit>();
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      cubit.cancelled();
      CustomSnackbar.info(
        context,
        title: 'Payment cancelled',
        message: 'Nothing was charged. You can try again any time.',
      );
      return;
    }
    cubit.declined(response.message ?? 'Payment failed. Nothing was charged.');
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  /// Opened only with what P1 returned — never an amount of our own.
  void _openSheet(BundleOrder order) {
    _razorpay.open(<String, dynamic>{
      'key': order.keyId,
      'order_id': order.razorpayOrderId,
      // Paise, and informational: Razorpay charges the order's amount.
      'amount': order.amountPaise,
      'currency': order.currency,
      'name': currentBranding.appName,
      'description': order.bundleTitle.isEmpty
          ? widget.bundle.card.title
          : order.bundleTitle,
      'send_sms_hash': false,
      'retry': {'enabled': false},
      'modal': {'confirm_close': true, 'handleback': true, 'escape': false},
      'prefill': <String, dynamic>{
        if (order.prefillName != null) 'name': order.prefillName,
        if (order.prefillEmail != null) 'email': order.prefillEmail,
        if (order.prefillContact != null) 'contact': order.prefillContact,
      },
    });
  }

  void _reloadDetail() =>
      context.read<BundleDetailCubit>().load(_bundleId, silent: true);

  Future<void> _confirmNewPrice(BundleOrder order) async {
    final cubit = context.read<BundleCheckoutCubit>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _PriceChangedSheet(order: order),
    );
    if (!mounted) return;
    if (ok == true) {
      cubit.confirmNewPrice(order);
    } else {
      cubit.reset();
      // Show the page at the price that is true now.
      _reloadDetail();
    }
  }

  void _showDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.bundle.card;
    return BlocConsumer<BundleCheckoutCubit, BundleCheckoutState>(
      listener: (context, state) {
        state.maybeWhen(
          priceChanged: _confirmNewPrice,
          orderReady: _openSheet,
          paid: (message) {
            CustomSnackbar.success(
              context,
              title: 'Courses unlocked',
              message: message,
            );
            context.read<BundleCheckoutCubit>().reset();
            // `isPurchased` flips, and the courses are in My Courses —
            // which heard about it through CourseAccessEvents.
            _reloadDetail();
          },
          stillPending: (message) =>
              _showDialog('Confirming your payment', message),
          refused: (message) {
            CustomSnackbar.info(
              context,
              title: 'Not available',
              message: message,
              duration: const Duration(seconds: 5),
            );
            context.read<BundleCheckoutCubit>().reset();
            // B2 now says why (`canPurchase: false` and its reason).
            _reloadDetail();
          },
          failed: (message, canRetry) {
            CustomSnackbar.error(
              context,
              title: canRetry ? 'Payment not completed' : 'Payment problem',
              message: canRetry
                  ? message
                  : '$message If money was deducted, please contact '
                        'support before trying again.',
            );
            context.read<BundleCheckoutCubit>().reset();
          },
          orElse: () {},
        );
      },
      builder: (context, checkout) {
        // Once Razorpay has reported success, the bar never offers Pay
        // again from here — only "check again".
        final awaiting = checkout.maybeWhen(
          confirming: (m) => m,
          stillPending: (m) => m,
          orElse: () => null,
        );
        if (awaiting != null) {
          return _AwaitingBar(
            message: awaiting,
            polling: checkout.maybeWhen(
              confirming: (_) => true,
              orElse: () => false,
            ),
            onCheckAgain: () =>
                context.read<BundleCheckoutCubit>().recheck(_bundleId),
          );
        }

        if (!card.canPurchase) {
          return _BlockedBar(
            purchased: card.isPurchased,
            reason:
                card.purchaseBlockedReason ??
                (card.isPurchased
                    ? 'You own every course in this bundle.'
                    : 'This bundle is not available right now.'),
          );
        }

        final busy = checkout.maybeWhen(
          creatingOrder: () => true,
          priceChanged: (_) => true,
          orderReady: (_) => true,
          verifying: () => true,
          orElse: () => false,
        );
        final total = widget.bundle.pricing.totalPayable;
        return StoreBottomBar(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(StoreFormat.money(total), style: AppTypography.h6Bold),
                  Text(
                    'Total payable',
                    style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StorePrimaryButton(
                  label: checkout.maybeWhen(
                    verifying: () => 'Confirming…',
                    orElse: () => busy ? 'Please wait…' : 'Pay now',
                  ),
                  icon: Icons.lock_rounded,
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () => context.read<BundleCheckoutCubit>().start(
                          _bundleId,
                          shownTotal: total,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Payment captured, unlock not yet confirmed.
class _AwaitingBar extends StatelessWidget {
  final String message;
  final bool polling;
  final VoidCallback onCheckAgain;

  const _AwaitingBar({
    required this.message,
    required this.polling,
    required this.onCheckAgain,
  });

  @override
  Widget build(BuildContext context) {
    return StoreBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StoreOutlinedButton(
            label: polling ? 'Confirming your payment…' : 'Check again',
            icon: Icons.refresh_rounded,
            loading: polling,
            onPressed: polling ? null : onCheckAgain,
          ),
        ],
      ),
    );
  }
}

/// `canPurchase: false` — the reason instead of a Buy button (§1 rule 6).
class _BlockedBar extends StatelessWidget {
  final bool purchased;
  final String reason;

  const _BlockedBar({required this.purchased, required this.reason});

  @override
  Widget build(BuildContext context) {
    final color = purchased ? AppColors.success : AppColors.mutedTextPrimary;
    return StoreBottomBar(
      child: Row(
        children: [
          Icon(
            purchased ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: AppTypography.bodyTextSemiBold.copyWith(
                color: purchased ? AppColors.textPrimary : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// P1 priced the bundle differently from what the page showed (§13).
class _PriceChangedSheet extends StatelessWidget {
  final BundleOrder order;

  const _PriceChangedSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Price updated', style: AppTypography.h6Bold),
            const SizedBox(height: 6),
            Text(
              'The price changed since you opened this bundle. Please '
              'check the new total before paying.',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            BundlePricingBreakdown(pricing: order.pricing),
            const SizedBox(height: 16),
            StorePrimaryButton(
              label: 'Pay ${StoreFormat.money(order.amountRupees)}',
              icon: Icons.lock_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
