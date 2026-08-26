import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/widgets/celebration_overlay.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/payment/data/models/payment_model.dart';
import 'package:nexora/features/payment/presentation/bloc/payment_cubit.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_outlined_action_button.dart';
import 'package:nexora/features/courses/presentation/bloc/course_pricing_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/pricing_tiers_cubit.dart';
import 'package:nexora/features/courses/presentation/widgets/choose_plan_bottom_sheet.dart';
import 'package:nexora/features/courses/presentation/widgets/enrollment_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "View Demo" + "Buy Now" / "Choose Plan" trio shown for non-purchased
/// courses. Handles Razorpay checkout end-to-end: resolves the tier
/// list, optionally pops a plan-picker sheet, fetches the per-tier
/// price breakdown, creates the backend order, opens Razorpay, then
/// verifies the signature on success.
///
/// When the host already knows the course's pricing tiers (e.g. the
/// course-detail page, which has loaded the full Course), it can pass
/// [tiers] so the CTA label flips to "Choose Plan" up front instead
/// of the user discovering the multi-tier nature only on tap. List
/// pages omit [tiers] and the label stays "Buy Now" — the tier-count
/// branch is resolved on the network round trip triggered by the tap.
class ViewDemoBuyNowRow extends StatelessWidget {
  final bool showViewDemo;
  final bool showViewDetails;
  final bool showBuyNow;
  final int courseId;

  /// Pre-loaded pricing tier list for the course. When non-null and
  /// `length > 1`, the buy CTA renders as "Choose Plan" instead of
  /// "Buy Now"; otherwise it stays as "Buy Now". The tier-resolution
  /// network round trip still runs on tap so the cubit chain has a
  /// fresh, server-authoritative list.
  final List<CoursePricingTier>? tiers;

  /// Replaces the default "Buy Now" text on the buy CTA. Only the
  /// plain-purchase label is overridden — the "Get Free Access" and
  /// "Choose Plan" branches still win when they apply, since those say
  /// something more specific about what the tap will do.
  final String? buyLabel;

  /// `true` when the course costs nothing (`Course.isCourseFree`, or
  /// every tier priced at 0). Flips the buy CTA from "Buy Now" to
  /// "Get Free Access" so the label matches what the tap actually does —
  /// the backend enrols the user outright and Razorpay never opens
  /// (see the `order.isCourseFree` short-circuit below).
  final bool isCourseFree;

  /// Fired once Razorpay reports `paymentSuccess` and the verify-payment
  /// API confirms. Each call site decides what to refresh — course-detail
  /// reloads the course, course-list flips the local purchased flag,
  /// home does nothing. The widget itself doesn't reach into ancestor
  /// cubits because it has no business knowing which screen it's on.
  final VoidCallback? onPurchased;

  const ViewDemoBuyNowRow({
    super.key,
    this.showViewDemo = true,
    this.showBuyNow = true,
    this.showViewDetails = true,
    required this.courseId,
    this.tiers,
    this.isCourseFree = false,
    this.buyLabel,
    this.onPurchased,
    this.buttonHeight = 50,
  });

  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    // Providers live ABOVE the inner stateful widget so the Razorpay
    // success/error callbacks (which run with the State element's context)
    // can still resolve PaymentCubit. If the providers were created inside
    // the State.build(), `this.context` of the State would be the parent
    // element of the providers and `context.read<PaymentCubit>()` would
    // throw "Could not find Provider".
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<PaymentCubit>()),
        BlocProvider(create: (_) => sl<PricingTiersCubit>()),
        BlocProvider(create: (_) => sl<CoursePricingCubit>()),
      ],
      child: ViewDemoBuyNowRowInner(
        courseId: courseId,
        showViewDemo: showViewDemo,
        showBuyNow: showBuyNow,
        showViewDetails: showViewDetails,
        tiers: tiers,
        isCourseFree: isCourseFree,
        buyLabel: buyLabel,
        onPurchased: onPurchased,
        buttonHeight: buttonHeight,
      ),
    );
  }
}

class ViewDemoBuyNowRowInner extends StatefulWidget {
  final int courseId;
  final bool showBuyNow;
  final bool showViewDemo;
  final bool showViewDetails;
  final List<CoursePricingTier>? tiers;
  final bool isCourseFree;
  final String? buyLabel;
  final VoidCallback? onPurchased;

  const ViewDemoBuyNowRowInner({
    super.key,
    required this.courseId,
    required this.showBuyNow,
    required this.showViewDemo,
    required this.showViewDetails,
    this.tiers,
    this.isCourseFree = false,
    this.buyLabel,
    this.onPurchased,
    required this.buttonHeight,
  });

  final double buttonHeight;

  @override
  State<ViewDemoBuyNowRowInner> createState() => ViewDemoBuyNowRowInnerState();
}

class ViewDemoBuyNowRowInnerState extends State<ViewDemoBuyNowRowInner> {
  late final Razorpay _razorpay;

  /// Latches while the enrolment sheet is shown so subsequent cubit
  /// emissions don't cause the BlocListener below to re-open it.
  bool _enrolmentSheetOpen = false;

  /// Same latch for the Choose Plan sheet — once the user opens it,
  /// state changes from the tiers cubit shouldn't pop a duplicate.
  bool _planSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    context.read<PaymentCubit>().verifyPayment(
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      // User closed the payment sheet, just reset to avoid showing an error.
      context.read<PaymentCubit>().reset();
      CustomSnackbar.info(
        context,
        title: 'Payment Cancelled',
        message: 'You have exited the payment process.',
      );
      return;
    }
    context.read<PaymentCubit>().onPaymentFailed(
      response.message ?? 'Payment failed',
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  void _openRazorpay(CreateOrderResponse order) {
    // Pull the live profile out of the global ProfileCubit so the Razorpay
    // sheet pre-fills contact/email — saves the user re-typing what they
    // already entered at signup. Same pattern used by the edit-profile route.
    final profile = sl<ProfileCubit>().state.maybeWhen(
      loaded: (p) => p,
      updated: (p) => p,
      updating: (p) => p,
      orElse: () => null,
    );
    final prefill = <String, dynamic>{
      if (profile?.name != null && profile!.name!.isNotEmpty)
        'name': profile.name,
      if (profile?.email != null && profile!.email!.isNotEmpty)
        'email': profile.email,
      if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty)
        'contact': profile.phoneNumber,
    };
    final options = <String, dynamic>{
      'key': order.keyId,
      'amount': order.amount,
      'currency': order.currency,
      'name': 'Crinza',
      'description': 'Course Purchase',
      'order_id': order.orderId,
      'send_sms_hash': false,
      'retry': {'enabled': false},
      'modal': {
        'confirm_close': true,
        'handleback': true,
        'escape': false,
      },
      if (prefill.isNotEmpty) 'prefill': prefill,
    };
    _razorpay.open(options);
  }

  /// Fetch the per-tier breakdown that the enrolment sheet renders.
  /// Pure forwarder — kept inline so the tiers-cubit listener and the
  /// plan-sheet `onProceed` callback share the same single call site.
  void _loadPricing(int priceId) {
    context.read<CoursePricingCubit>().load(
      courseId: widget.courseId,
      priceId: priceId,
    );
  }

  /// Opens the tier-picker sheet. Captured cubits over `context` are
  /// passed by closure so we don't read the descendant `BuildContext`
  /// after the async gap that the sheet introduces.
  void _openChoosePlanSheet(List<CoursePricingTier> tiers) {
    final tiersCubit = context.read<PricingTiersCubit>();
    _planSheetOpen = true;
    ChoosePlanBottomSheet.show(
      context,
      tiers: tiers,
      onProceed: (selected) => _loadPricing(selected.coursePricingId),
    ).whenComplete(() {
      _planSheetOpen = false;
      // Reset so a second tap re-fires the tiers BlocListener (Bloc
      // suppresses identical states by default).
      tiersCubit.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Tier list landed — branch on count. Single tier auto-flows
        // into the pricing breakdown; multi-tier pops the picker sheet.
        // Empty list surfaces a snackbar (free course / unconfigured).
        BlocListener<PricingTiersCubit, PricingTiersState>(
          listener: (context, state) {
            state.maybeWhen(
              loaded: (tiers) {
                if (_planSheetOpen) return;
                if (tiers.isEmpty) {
                  CustomSnackbar.error(
                    context,
                    title: 'Pricing unavailable',
                    message: 'This course has no buyable plan right now.',
                  );
                  return;
                }
                if (tiers.length == 1) {
                  _loadPricing(tiers.first.coursePricingId);
                } else {
                  _openChoosePlanSheet(tiers);
                }
              },
              error: (message) => CustomSnackbar.error(
                context,
                title: 'Pricing unavailable',
                message: message,
              ),
              orElse: () {},
            );
          },
        ),
        // Pricing breakdown landed → open the enrolment sheet. The
        // sheet's Proceed button kicks off create-order on PaymentCubit.
        BlocListener<CoursePricingCubit, CoursePricingState>(
          listener: (context, state) {
            state.maybeWhen(
              loaded: (pricing) {
                if (_enrolmentSheetOpen) return;
                _enrolmentSheetOpen = true;
                final paymentCubit = context.read<PaymentCubit>();
                final pricingCubit = context.read<CoursePricingCubit>();
                EnrollmentBottomSheet.show(
                  context,
                  courseId: widget.courseId,
                  cubit: pricingCubit,
                  // v2 derives the chargeable amount server-side from
                  // `(courseId, priceId)` so we forward the tier id
                  // the pricing breakdown was bound to — amount is calculated
                  // on the backend, but we pass the coupon code if applied.
                  onProceed: (current) => paymentCubit.createOrder(
                    courseId: widget.courseId,
                    priceId: current.coursePriceId,
                    couponCode: pricingCubit.appliedCouponCode,
                  ),
                ).whenComplete(() {
                  _enrolmentSheetOpen = false;
                  if (!mounted) return;
                  pricingCubit.reset();
                });
              },
              error: (message) => CustomSnackbar.error(
                context,
                title: 'Pricing unavailable',
                message: message,
              ),
              orElse: () {},
            );
          },
        ),
        // Payment → Razorpay open + verification snackbars.
        BlocListener<PaymentCubit, PaymentState>(
          listener: (context, state) {
            state.maybeWhen(
              orderReady: (order) {
                if (order.isCourseFree) {
                  // Backend already enrolled the user (free course or
                  // 100%-off coupon) — skip Razorpay and run the same
                  // success path we'd run after a paid checkout.
                  //
                  // A snackbar under-sells the moment the student gains
                  // access, so this branch gets the full celebration.
                  // It sits on the root overlay, which is what lets it
                  // survive the course refetch `onPurchased` kicks off.
                  CelebrationOverlay.show(
                    context,
                    emoji: '🎉',
                    title: 'Congratulations!',
                    message: 'Course Unlocked',
                    quote: 'Your free access is ready. Jump in and '
                        'start learning.',
                  );
                  widget.onPurchased?.call();
                  return;
                }
                _openRazorpay(order);
              },
              paymentSuccess: () {
                CustomSnackbar.success(
                  context,
                  title: 'Payment Successful!',
                  message: 'You are now enrolled in this course.',
                );
                widget.onPurchased?.call();
              },
              paymentFailed: (message) => CustomSnackbar.error(
                context,
                title: 'Payment Failed',
                message: message,
              ),
              error: (message) => CustomSnackbar.error(
                context,
                title: 'Error',
                message: message,
              ),
              orElse: () {},
            );
          },
        ),
      ],
      child: BlocBuilder<PaymentCubit, PaymentState>(
        builder: (context, paymentState) {
          return BlocBuilder<CoursePricingCubit, CoursePricingState>(
            builder: (context, pricingState) {
              return BlocBuilder<PricingTiersCubit, PricingTiersState>(
                builder: (context, tiersState) {
                  final isLoading = paymentState.maybeWhen(
                        creatingOrder: () => true,
                        verifying: () => true,
                        orElse: () => false,
                      ) ||
                      pricingState.maybeWhen(
                        loading: () => true,
                        orElse: () => false,
                      ) ||
                      tiersState.maybeWhen(
                        loading: () => true,
                        orElse: () => false,
                      );
                  // A course is free when the host said so, or when
                  // every pre-loaded tier is priced at 0.
                  final tiers = widget.tiers;
                  final isFree = widget.isCourseFree ||
                      (tiers != null &&
                          tiers.isNotEmpty &&
                          tiers.every((t) => t.calculatedFinalPrice <= 0));
                  // Label depends on the pre-loaded tier count when
                  // the host shipped one. Otherwise it stays "Buy
                  // Now" and the multi-tier branch reveals itself on
                  // tap when the tiers cubit emits.
                  final ctaLabel = isLoading
                      ? 'Please wait...'
                      : isFree
                          ? 'Get Free Access'
                          : ((tiers?.length ?? 0) > 1
                              ? 'Choose Plan'
                              : (widget.buyLabel ?? 'Buy Now'));
                  return Row(
                    children: [
                      if (widget.showViewDemo) ...[
                        Expanded(
                          child: CustomOutlinedActionButton(
                            isFormFilled: true,
                            name: 'View Demo',
                            buttonHeight: widget.buttonHeight,
                            borderRadius: 50,
                            onTap: (_, __, ___) {
                              // Todo: Need to implement the demo video feature in the backend and then link it here.
                            },
                          ),
                        ),
                        if (widget.showViewDetails || widget.showBuyNow)
                          SizedBox(width: Screen.getHorizontalSize(12)),
                      ],

                      if (widget.showViewDetails) ...[
                        Expanded(
                          child: CustomOutlinedActionButton(
                            isFormFilled: true,
                            name: 'View Details',
                            buttonHeight: widget.buttonHeight,
                            borderRadius: 50,
                            onTap: (_, __, ___) {
                              context.push(
                                '${AppRoutes.courseDetail}?courseId=${widget.courseId}',
                              );
                            },
                          ),
                        ),
                        if (widget.showBuyNow)
                          SizedBox(width: Screen.getHorizontalSize(12)),
                      ],

                      if (widget.showBuyNow)
                        Expanded(
                          child: CustomActionButton(
                            isFormFilled: !isLoading,
                            name: ctaLabel,
                            buttonHeight: widget.buttonHeight,
                            onTap: (_, __, ___) {
                              if (isLoading) return;
                              context
                                  .read<PricingTiersCubit>()
                                  .load(widget.courseId);
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
