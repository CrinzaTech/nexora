import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/data/models/webinar_payment_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_checkout_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_detail_cubit.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/webinar_share.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_card.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_cover.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_external_join.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_live_badge.dart';
import 'package:nexora/features/workshop_pass/presentation/workshop_pass_entry.dart';

/// A single webinar: what it is, who is teaching it, when it starts —
/// and the one button that gets the learner in.
///
/// **Joining is a native call, not a link.** The learner is signed in and
/// already an `app_users` row, so A3 seats them on the account token and
/// the room opens in the app. `shareLink` belongs to the share button
/// beside it: opening it here would hand a signed-in user to the
/// website's stranger flow and ask them to register all over again.
///
/// What "join" *means* is decided by `joinMode`, not by `platform` — a
/// stream opens the player, a Zoom or Meet link leaves the app, and a
/// workshop shows a venue. And for a paid webinar the button buys the
/// seat first: **there is no seat until the payment verifies.**
class WebinarDetailPage extends StatelessWidget {
  final String slug;

  const WebinarDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<WebinarDetailCubit>()..load(slug)),
        // Created alongside the detail rather than on demand: the Razorpay
        // sheet reports through listeners the widget registers in
        // initState, so the cubit that receives them has to exist before
        // the first tap, not after it.
        BlocProvider(create: (_) => sl<WebinarCheckoutCubit>()),
      ],
      child: _WebinarDetailView(slug: slug),
    );
  }
}

class _WebinarDetailView extends StatelessWidget {
  final String slug;

  const _WebinarDetailView({required this.slug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CustomAppBar(title: 'Webinar'),
      body: SafeArea(
        child: BlocBuilder<WebinarDetailCubit, WebinarDetailState>(
          builder: (context, state) {
            return state.maybeWhen(
              loaded: (webinar) => _LoadedBody(webinar: webinar, slug: slug),
              error: (message) => _ErrorView(message: message, slug: slug),
              orElse: () => const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  final WebinarDetail webinar;
  final String slug;

  const _LoadedBody({required this.webinar, required this.slug});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                context.read<WebinarDetailCubit>().silentRefresh(slug),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Screen.getPadding(horizontal: 20, vertical: 16),
              children: [
                _Hero(webinar: webinar),
                SizedBox(height: Screen.getVerticalSize(16)),
                if (webinar.orgName != null) ...[
                  _OrgRow(webinar: webinar),
                  SizedBox(height: Screen.getVerticalSize(12)),
                ],
                Text(
                  webinar.title,
                  style: AppTypography.h4SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSizeCapped(20),
                    height: 1.25,
                  ),
                ),
                if (webinar.educatorName != null) ...[
                  SizedBox(height: Screen.getVerticalSize(8)),
                  _IconLine(
                    icon: Icons.person_outline_rounded,
                    text: webinar.educatorName!,
                  ),
                ],
                SizedBox(height: Screen.getVerticalSize(12)),
                _PriceRow(webinar: webinar),
                SizedBox(height: Screen.getVerticalSize(14)),
                _ScheduleCard(webinar: webinar, slug: slug),
                if (!webinar.isStream) ...[
                  SizedBox(height: Screen.getVerticalSize(12)),
                  _HowItHappens(webinar: webinar),
                ],
                if (webinar.isRegistered && webinar.isAuthenticated) ...[
                  SizedBox(height: Screen.getVerticalSize(12)),
                  const _RegisteredNotice(),
                ],
                // Only for a paid workshop this learner has bought —
                // `showsWorkshopPass` mirrors the server's own check, so
                // the card appears exactly where the call would succeed.
                if (showsWorkshopPass(webinar)) ...[
                  SizedBox(height: Screen.getVerticalSize(12)),
                  _WorkshopPassCta(webinar: webinar),
                ],
                // Shown whenever the door is shut, **even if the server
                // sent no sentence**. `canJoin` also goes false when an
                // in-person workshop fills up, and a greyed-out button
                // with nothing next to it reads as a broken page rather
                // than as "this one is full".
                if (!webinar.canJoin) ...[
                  SizedBox(height: Screen.getVerticalSize(12)),
                  _BlockedNotice(reason: webinar.joinBlockedReason),
                ],
                if (webinar.description != null) ...[
                  SizedBox(height: Screen.getVerticalSize(20)),
                  Text(
                    'About this webinar',
                    style: AppTypography.h5SemiBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: Screen.getFontSizeCapped(16),
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(8)),
                  Text(
                    webinar.description!,
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                      fontSize: Screen.getFontSize(14),
                      height: 1.5,
                    ),
                  ),
                ],
                SizedBox(height: Screen.getVerticalSize(20)),
              ],
            ),
          ),
        ),
        _JoinBar(webinar: webinar, slug: slug),
      ],
    );
  }
}

/// Cover image with the LIVE badge — the one place `isLive` is allowed
/// to light something up.
///
/// The cover is shown whole rather than cropped to the 16:9 box, and
/// tapping it opens the full-screen viewer, the same one a profile
/// picture opens into. An educator's poster usually carries the title,
/// the date and a face; a crop keeps roughly the middle third of that.
class _Hero extends StatelessWidget {
  final WebinarDetail webinar;

  const _Hero({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final hasCover = webinar.thumbnailUrl?.isNotEmpty ?? false;

    return Stack(
      children: [
        GestureDetector(
          onTap: hasCover
              ? () => showWebinarCover(context, webinar.thumbnailUrl)
              : null,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              child: WebinarCoverImage(
                url: webinar.thumbnailUrl,
                fallback: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Icon(
                    Icons.video_camera_front_outlined,
                    color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                    size: Screen.getSize(48),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasCover)
          const Positioned(
            right: 12,
            bottom: 12,
            child: WebinarCoverExpandButton(),
          ),
        if (webinar.isLive)
          const Positioned(
            top: 12,
            left: 12,
            child: WebinarLiveBadge(scale: 1.15),
          ),
        // Only for the modes that change what joining does — a "Crinza
        // Live" badge on the ordinary case would be noise on every card.
        if (!webinar.isStream)
          Positioned(
            top: 12,
            right: 12,
            child: WebinarPlatformBadge(
              platformName: webinar.platformName,
              joinMode: webinar.joinMode,
            ),
          ),
      ],
    );
  }
}

/// What the seat costs, if anything.
///
/// **Read from `isFree`, never from `isPaid`** — a paid webinar
/// discounted to zero is free, and "Pay 0.00" is not a thing to show
/// anyone. `price` already has the discount applied and any internet
/// charges folded in, so there is no arithmetic here and no tax to add.
class _PriceRow extends StatelessWidget {
  final WebinarDetail webinar;

  const _PriceRow({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final original = webinar.originalPrice;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          WebinarFormatting.price(webinar),
          style: AppTypography.h4SemiBold.copyWith(
            color: webinar.isFree ? AppColors.success : AppColors.textPrimary,
            fontSize: Screen.getFontSizeCapped(18),
          ),
        ),
        // Present only when a discount actually moved the price, so it
        // never shows the same number struck through beside itself.
        if (!webinar.isFree && original != null) ...[
          SizedBox(width: Screen.getHorizontalSize(8)),
          Text(
            WebinarFormatting.rupees(original),
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(13),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
        if (webinar.isRegistered && webinar.isAuthenticated) ...[
          SizedBox(width: Screen.getHorizontalSize(10)),
          Icon(
            Icons.verified_rounded,
            size: Screen.getSize(16),
            color: AppColors.success,
          ),
        ],
      ],
    );
  }
}

/// Says where a non-streamed webinar actually happens, before the
/// learner commits to it. The venue itself stays behind the registration
/// gate — that is the whole point of the feature — but "this is on Zoom"
/// or "this is in person" is not something to discover afterwards.
class _HowItHappens extends StatelessWidget {
  final WebinarDetail webinar;

  const _HowItHappens({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final isVenue = webinar.isInPerson;

    return _Notice(
      icon: isVenue ? Icons.location_on_outlined : Icons.videocam_outlined,
      color: AppColors.primary,
      text: isVenue
          ? 'This is an in-person workshop. The venue is shared with you '
                'once you register.'
          : 'This session runs on ${webinar.platformName}. The meeting '
                'link is shared with you once you register.',
    );
  }
}

class _OrgRow extends StatelessWidget {
  final WebinarDetail webinar;

  const _OrgRow({required this.webinar});

  @override
  Widget build(BuildContext context) {
    final logoSize = Screen.getSize(28);

    return Row(
      children: [
        if (webinar.orgLogoUrl != null) ...[
          CustomNetworkImage(
            url: webinar.orgLogoUrl,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            errorWidget: const SizedBox.shrink(),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
        ],
        Flexible(
          child: Text(
            webinar.orgName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(13),
            ),
          ),
        ),
      ],
    );
  }
}

/// When it runs, and how long until then.
class _ScheduleCard extends StatelessWidget {
  final WebinarDetail webinar;
  final String slug;

  const _ScheduleCard({required this.webinar, required this.slug});

  @override
  Widget build(BuildContext context) {
    final duration = WebinarFormatting.duration(webinar);

    return Container(
      width: double.infinity,
      padding: Screen.getPadding(all: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: AppDecorations.cardBorder(
          lightColor: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconLine(
            icon: Icons.event_rounded,
            text: WebinarFormatting.schedule(webinar),
            emphasise: true,
          ),
          if (duration.isNotEmpty) ...[
            SizedBox(height: Screen.getVerticalSize(8)),
            _IconLine(icon: Icons.timelapse_rounded, text: duration),
          ],
          SizedBox(height: Screen.getVerticalSize(8)),
          WebinarStartLabel(
            webinar: webinar,
            fontSize: Screen.getFontSize(13),
            // The instant the wait runs out is the instant the gate can
            // change — re-read it rather than leave a stale "Starts in
            // 0s" next to a button that no longer matches.
            onElapsed: () =>
                context.read<WebinarDetailCubit>().silentRefresh(slug),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasise;

  const _IconLine({
    required this.icon,
    required this.text,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: Screen.getSize(16),
          color: emphasise ? AppColors.primary : AppColors.mutedTextPrimary,
        ),
        SizedBox(width: Screen.getHorizontalSize(8)),
        Expanded(
          child: Text(
            text,
            style:
                (emphasise
                        ? AppTypography.bodyTextLargeSemiBold
                        : AppTypography.bodyTextLargeMedium)
                    .copyWith(
                      color: emphasise
                          ? AppColors.textPrimary
                          : AppColors.mutedTextPrimary,
                      fontSize: Screen.getFontSize(13),
                    ),
          ),
        ),
      ],
    );
  }
}

class _RegisteredNotice extends StatelessWidget {
  const _RegisteredNotice();

  @override
  Widget build(BuildContext context) {
    return _Notice(
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      // Registration is not a gate — the API lets a registered learner
      // rejoin freely — so this reassures rather than instructs.
      text: "You're registered for this webinar.",
    );
  }
}

/// The way to the entry pass, for a workshop this learner has bought.
///
/// Given a card of its own rather than folded into the Join button
/// because the two are different errands: the join button hands over the
/// venue, and this hands over the thing scanned at its door. An attendee
/// arriving at the workshop is looking for the ticket, not for directions
/// they already took.
class _WorkshopPassCta extends StatelessWidget {
  final WebinarDetail webinar;

  const _WorkshopPassCta({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      onTap: () => openWorkshopPass(
        context,
        slug: webinar.slug,
        workshopTitle: webinar.title,
      ),
      child: Container(
        padding: Screen.getPadding(all: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: AppDecorations.cardBorder(
            lightColor: AppColors.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: Screen.getSize(20),
              color: AppColors.primary,
            ),
            SizedBox(width: Screen.getHorizontalSize(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your entry pass',
                    style: AppTypography.bodyTextLargeSemiBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: Screen.getFontSize(14),
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(2)),
                  Text(
                    'Show this at the door on the day.',
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                      fontSize: Screen.getFontSize(12),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: Screen.getSize(20),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  final String reason;

  const _BlockedNotice({required this.reason});

  @override
  Widget build(BuildContext context) {
    // `joinBlockedReason` is written for the learner by the backend —
    // shown verbatim rather than re-worded per status. It carries the
    // sold-out sentence for a workshop that filled, among others.
    //
    // The fallback is only for a `canJoin: false` that arrives with no
    // sentence at all: something still has to be said, because a button
    // that has gone quiet with nothing beside it reads as a bug.
    return _Notice(
      icon: Icons.info_outline_rounded,
      color: AppColors.warning,
      text: reason.trim().isEmpty
          ? 'This webinar is not open to join right now.'
          : reason,
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Notice({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(all: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Screen.getSize(18), color: color),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(13),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pinned action bar.
///
/// One button, and what it does depends on two things the server told
/// us — never on a flag this screen could set for itself:
///
///  * **`isFree`** decides whether it buys first. A paid webinar grants
///    no seat until the payment verifies, so for one they have not
///    bought the button opens checkout rather than the room.
///  * **`joinMode`** decides what "in" means: the player, a Zoom link,
///    or an address.
///
/// Stateful because Razorpay's plugin reports through listeners that
/// must be registered before the first tap and cleared on dispose —
/// leaving them attached is how a second sheet ends up with two
/// handlers verifying the same payment twice.
class _JoinBar extends StatefulWidget {
  final WebinarDetail webinar;
  final String slug;

  const _JoinBar({required this.webinar, required this.slug});

  @override
  State<_JoinBar> createState() => _JoinBarState();
}

class _JoinBarState extends State<_JoinBar> {
  late final Razorpay _razorpay;

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
    // Without this the listeners outlive the screen and a later payment
    // is verified by a handler holding a dead context.
    _razorpay.clear();
    super.dispose();
  }

  /// **P2 is what grants the seat.** A completed sheet is not a purchase
  /// until the server has verified the signature and confirmed with
  /// Razorpay that the money actually moved.
  void _onPaymentSuccess(PaymentSuccessResponse response) {
    context.read<WebinarCheckoutCubit>().verify(
      widget.slug,
      // Byte-for-byte as Razorpay handed them over.
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final cubit = context.read<WebinarCheckoutCubit>();
    // Closing the sheet charges nothing and leaves a harmless CREATED
    // order behind — an informational nudge, not an error.
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

  void _openCheckoutSheet(WebinarOrder order) {
    _razorpay.open(<String, dynamic>{
      // Per-environment, from P1 — test and live differ, so it is never
      // hardcoded here.
      'key': order.keyId,
      // PAISE. `amountRupees` is for the label above; sending it here
      // would charge ₹9.18 for a ₹918 webinar.
      'amount': order.amountPaise,
      'currency': order.currency,
      'name': 'Crinza',
      'description': order.webinarTitle.isEmpty
          ? widget.webinar.title
          : order.webinarTitle,
      'order_id': order.razorpayOrderId,
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

  /// Where a verified payment lands.
  ///
  /// **For a paid workshop the pass is the receipt.** It exists the
  /// moment `verify-payment` succeeds, and it is what the attendee
  /// actually came away with — so it is shown rather than left to be
  /// found later. The venue is one Directions button away on that
  /// screen, so nothing is lost by not going to the room first.
  ///
  /// Everything else goes straight in, as before.
  Future<void> _openAfterPayment() async {
    final webinar = widget.webinar;
    if (webinar.isInPerson && !webinar.isFree) {
      await openWorkshopPass(
        context,
        slug: widget.slug,
        workshopTitle: webinar.title,
      );
      if (!mounted) return;
      context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
      return;
    }
    await _openRoom();
  }

  /// Into the room. A3 runs there — idempotent, so this is also the
  /// path a learner who already has a seat takes.
  Future<void> _openRoom() async {
    final webinar = widget.webinar;
    await context.push(
      '${AppRoutes.webinarRoom}'
      '?slug=${Uri.encodeComponent(webinar.slug)}'
      '&roomId=${Uri.encodeComponent(webinar.roomId)}'
      '&title=${Uri.encodeComponent(webinar.title)}'
      '&thumbnailUrl=${Uri.encodeComponent(webinar.thumbnailUrl ?? '')}'
      '&educatorName=${Uri.encodeComponent(webinar.educatorName ?? '')}'
      '&isFree=${webinar.isFree}'
      // Carried so the room opens on the right screen from the first
      // frame rather than swapping to it once A3 answers.
      '&isStream=${webinar.isStream}',
    );
    if (!mounted) return;
    // A3 flips `isRegistered`, and the class may have started or
    // finished while they were in the room.
    context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    final webinar = widget.webinar;
    final canJoin = webinar.canJoin;
    final shareLink = webinar.shareLink;

    return BlocConsumer<WebinarCheckoutCubit, WebinarCheckoutState>(
      listener: (context, state) {
        state.maybeWhen(
          orderReady: _openCheckoutSheet,
          paid: (session) {
            CustomSnackbar.success(
              context,
              title: 'Payment successful',
              message: "You're registered for this webinar.",
            );
            context.read<WebinarCheckoutCubit>().reset();
            // The detail re-read flips `isRegistered`, which is what
            // turns this button from "Buy" into "Join".
            context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
            _openAfterPayment();
          },
          alreadyPaid: (message) {
            context.read<WebinarCheckoutCubit>().reset();
            context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
            _openRoom();
          },
          refused: (message) {
            // Information, not a red failure: nothing was charged and
            // the learner did nothing wrong — the last seat went. Shown
            // with the server's own sentence.
            CustomSnackbar.info(
              context,
              title: 'Not available',
              message: message,
              duration: const Duration(seconds: 5),
            );
            context.read<WebinarCheckoutCubit>().reset();
            // Re-read the detail: `canJoin` is false now, which turns
            // the Buy button off and puts the reason under it, so the
            // screen stops offering something that cannot happen.
            context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
          },
          failed: (message, canRetry) {
            CustomSnackbar.error(
              context,
              title: canRetry ? 'Payment not completed' : 'Payment problem',
              message: canRetry
                  ? message
                  : '$message Please contact support before trying again.',
            );
            context.read<WebinarCheckoutCubit>().reset();
          },
          unresolved: (message) {
            // Money may have left their account while we could not reach
            // Razorpay to confirm it. The one thing never offered here
            // is "pay again".
            _showConfirmingDialog(message);
            context.read<WebinarCheckoutCubit>().reset();
          },
          orElse: () {},
        );
      },
      builder: (context, checkout) {
        final busy = checkout.maybeWhen(
          creatingOrder: () => true,
          orderReady: (_) => true,
          verifying: () => true,
          orElse: () => false,
        );

        return Container(
          padding: Screen.getPadding(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: CustomActionButton(
                    isFormFilled: canJoin && !busy,
                    name: busy
                        ? _busyLabel(checkout)
                        : _joinLabel(webinar),
                    shouldAnimate: false,
                    tone: webinar.isLive
                        ? CustomActionButtonTone.error
                        : CustomActionButtonTone.primary,
                    leading: Padding(
                      padding: EdgeInsets.only(
                        right: Screen.getHorizontalSize(8),
                      ),
                      child: Icon(
                        _joinIcon(webinar),
                        color: AppColors.alwaysWhite,
                        size: Screen.getSize(20),
                      ),
                    ),
                    onTap: (startLoading, stopLoading, btnState) async {
                      if (!canJoin || busy) return;
                      // The whole branch, in one line: buy it, or go in.
                      if (webinar.needsPayment) {
                        await context.read<WebinarCheckoutCubit>().start(
                          widget.slug,
                        );
                        return;
                      }
                      await _openRoom();
                    },
                  ),
                ),
                // `shareLink` is null exactly when `canJoin` is false, so
                // the share button disappears with the join button rather
                // than passing on a link that would reject whoever
                // opened it.
                if (shareLink != null) ...[
                  SizedBox(width: Screen.getHorizontalSize(10)),
                  _ShareButton(webinar: webinar, shareLink: shareLink),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmingDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirming your payment'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<WebinarDetailCubit>().silentRefresh(widget.slug);
            },
            // Refresh, never "pay again" — a second payment for one seat
            // is the outcome this whole branch exists to prevent.
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  String _busyLabel(WebinarCheckoutState state) => state.maybeWhen(
    verifying: () => 'Confirming payment…',
    orElse: () => 'Please wait…',
  );

  /// What the button honestly does next. Note the meeting and workshop
  /// wording changes with `isRegistered`: before registering, the tap
  /// buys them the link; after, it hands it over.
  String _joinLabel(WebinarDetail webinar) {
    if (webinar.needsPayment) {
      return 'Buy for ${WebinarFormatting.price(webinar)}';
    }
    switch (webinar.joinMode) {
      case WebinarJoinMode.meeting:
        return webinar.isRegistered
            ? 'Join on ${webinar.platformName}'
            : 'Get the meeting link';
      case WebinarJoinMode.location:
        return webinar.isRegistered ? 'View venue details' : 'Get the venue';
      case WebinarJoinMode.stream:
        return webinar.isLive ? 'Join Live Now' : 'Join Webinar';
    }
  }

  IconData _joinIcon(WebinarDetail webinar) {
    if (webinar.needsPayment) return Icons.lock_open_rounded;
    switch (webinar.joinMode) {
      case WebinarJoinMode.meeting:
        return Icons.open_in_new_rounded;
      case WebinarJoinMode.location:
        return Icons.location_on_outlined;
      case WebinarJoinMode.stream:
        return webinar.isLive
            ? Icons.play_circle_fill_rounded
            : Icons.video_call_rounded;
    }
  }
}

/// Passes the webinar on to someone else. What they get is the public
/// web page, where a stranger registers with their phone number — which
/// is the whole point of the link, and the opposite of what the Join
/// button beside it does.
///
/// Stateful only to show that something is happening while the cover art
/// is fetched: the share sheet cannot open until the file is on disk, and
/// a button that does nothing for a second reads as broken.
class _ShareButton extends StatefulWidget {
  final WebinarDetail webinar;
  final String shareLink;

  const _ShareButton({required this.webinar, required this.shareLink});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _preparing = false;

  Future<void> _share() async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      await WebinarShare.share(
        context: context,
        webinar: widget.webinar,
        shareLink: widget.shareLink,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the share sheet.')),
        );
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(52);

    return InkWell(
      onTap: _preparing ? null : _share,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: _preparing
            ? SizedBox(
                width: Screen.getSize(18),
                height: Screen.getSize(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                Icons.share_outlined,
                color: AppColors.primary,
                size: Screen.getSize(20),
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String slug;

  const _ErrorView({required this.message, required this.slug});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: AppColors.grey300,
            ),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              'Webinar unavailable',
              textAlign: TextAlign.center,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(16),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(20)),
            CustomActionButton(
              isFormFilled: true,
              name: 'Retry',
              buttonWidth: Screen.getHorizontalSize(160),
              onTap: (startLoading, stopLoading, btnState) {
                startLoading();
                context
                    .read<WebinarDetailCubit>()
                    .load(slug)
                    .whenComplete(() => stopLoading());
              },
            ),
          ],
        ),
      ),
    );
  }
}
