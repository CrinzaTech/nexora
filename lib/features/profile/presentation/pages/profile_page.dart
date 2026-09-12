import 'dart:io' show Platform;
import 'package:nexora/features/profile/domain/usecases/delete_account_usecase.dart';
import 'package:nexora/features/profile/presentation/widgets/delete_account_dialog.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/core/network/token_refresh_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/logout_dialog.dart';
import 'package:nexora/features/profile/domain/support_channel.dart';
import 'package:nexora/features/profile/domain/usecases/get_app_rating_url_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/get_org_info_usecase.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_version_text.dart';
import '../widgets/logout_button.dart';
import '../widgets/person_card_widget.dart';
import '../widgets/profile_card_error.dart';
import '../widgets/profile_card_shimmer.dart';
import '../widgets/profile_list_tile.dart';

/// Profile Screen
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Latches while an account-deletion request is in flight, so the tile
  /// can't start a second one. See [_handleDeleteAccount].
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // ProfileCubit lives at the root (see main.dart). Bootstrap a load
    // only when nothing has been fetched yet — Home may have already
    // primed it on first launch.
    final cubit = context.read<ProfileCubit>();
    final shouldLoad = cubit.state.maybeWhen(
      initial: () => true,
      error: (_) => true,
      orElse: () => false,
    );
    if (shouldLoad) cubit.loadProfile();
  }

  Future<void> _onRefresh() async {
    await context.read<ProfileCubit>().loadProfile(force: true);
  }

  // ----------------------------------------------------------------
  // Organization info helpers
  // ----------------------------------------------------------------

  /// Opens Terms & Conditions: calls API with termsAndCondition=true
  /// then pushes the PDF URL into the document viewer.
  Future<void> _openTermsAndConditions() async {
    _showLoadingSnackbar('Loading Terms & Conditions…');

    final result = await sl<GetOrgInfoUseCase>()(termsAndCondition: true);

    if (!mounted) return;

    result.fold(
      (failure) {
        CustomSnackbar.error(context, title: 'Error', message: failure.message);
      },
      (info) async {
        final url = info.termsAndConditionUrl;
        if (url == null || url.isEmpty) {
          CustomSnackbar.warning(
            context,
            title: 'Unavailable',
            message: 'Terms & Conditions link is not available right now.',
          );
          return;
        }
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          CustomSnackbar.error(
            context,
            title: 'Cannot Open',
            message: 'Unable to open Terms & Conditions.',
          );
        }
      },
    );
  }

  /// Opens Refund Policy: calls API with refundPolicy=true
  /// then pushes the PDF URL into the document viewer.
  Future<void> _openRefundPolicy() async {
    _showLoadingSnackbar('Loading Refund Policy…');

    final result = await sl<GetOrgInfoUseCase>()(refundPolicy: true);

    if (!mounted) return;

    result.fold(
      (failure) {
        CustomSnackbar.error(context, title: 'Error', message: failure.message);
      },
      (info) async {
        final url = info.refundPolicyUrl;
        if (url == null || url.isEmpty) {
          CustomSnackbar.warning(
            context,
            title: 'Unavailable',
            message: 'Refund Policy link is not available right now.',
          );
          return;
        }
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          CustomSnackbar.error(
            context,
            title: 'Cannot Open',
            message: 'Unable to open Refund Policy.',
          );
        }
      },
    );
  }

  /// "Contact for Support" — one tile, two destinations.
  ///
  /// Calls the org-info API with `whatsappNumber=true` and branches on
  /// the org's `allowWhatsappSupport` flag:
  ///   - `true`  → launch `https://wa.me/<number>` (the original flow)
  ///   - `false` → open in-app personal chat with the org's faculty
  ///
  /// Deliberately a single tile rather than one per channel: an org
  /// runs one or the other, so showing both would always leave a dead
  /// entry on the screen.
  Future<void> _contactSupport() async {
    _showLoadingSnackbar('Connecting to support…');

    final result = await sl<GetOrgInfoUseCase>()(whatsappNumber: true);

    if (!mounted) return;

    result.fold(
      (failure) {
        CustomSnackbar.error(context, title: 'Error', message: failure.message);
      },
      (info) async {
        switch (resolveSupportChannel(info)) {
          case SupportChannel.personalChat:
            context.push(AppRoutes.directChatInbox);
          case SupportChannel.unavailable:
            CustomSnackbar.warning(
              context,
              title: 'Unavailable',
              message: 'Support contact is not available right now.',
            );
          case SupportChannel.whatsapp:
            final uri = whatsappUriFor(info);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                CustomSnackbar.error(
                  context,
                  title: 'Cannot Open WhatsApp',
                  message: 'Make sure WhatsApp is installed on your device.',
                );
              }
            }
        }
      },
    );
  }

  /// Opens the store listing for "Rate this app": calls the app-rating-url
  /// API with the current platform, then launches the returned Play
  /// Store / App Store URL.
  Future<void> _rateApp() async {
    _showLoadingSnackbar('Opening store…');

    final deviceType = Platform.isIOS ? 'ios' : 'android';
    final result = await sl<GetAppRatingUrlUseCase>()(deviceType);

    if (!mounted) return;

    result.fold(
      (failure) {
        debugPrint('[RateApp] failure: $failure');
        // A 404 just means the org hasn't configured a rating URL for
        // this platform — treat it like "no link available", not an
        // error worth surfacing.
        final isNotFound = failure.maybeWhen(
          server: (_, statusCode) => statusCode == 404,
          orElse: () => false,
        );
        if (isNotFound) return;
        CustomSnackbar.error(context, title: 'Error', message: failure.message);
      },
      (info) async {
        final url = info.ratingUrl;
        debugPrint('[RateApp] deviceType=$deviceType ratingUrl=$url');
        if (url == null || url.isEmpty) {
          // No rating URL configured for this org/platform — nothing to
          // redirect to, so stay quiet instead of showing an error.
          return;
        }

        final uri = Uri.parse(url);
        // Don't gate on canLaunchUrl(): on Android 11+ it can report
        // false for store links (package-visibility) even when the
        // Play Store / App Store handler is present. Launch straight
        // into the external store app and only surface an error if the
        // launch itself throws.
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          debugPrint('[RateApp] launched=$launched uri=$uri');
          if (!launched && mounted) {
            CustomSnackbar.error(
              context,
              title: 'Cannot Open',
              message: 'Unable to open the store page.',
            );
          }
        } catch (e) {
          debugPrint('[RateApp] launch error: $e');
          if (mounted) {
            CustomSnackbar.error(
              context,
              title: 'Cannot Open',
              message: 'Unable to open the store page.',
            );
          }
        }
      },
    );
  }

  /// Shares the app's store link through the native share sheet
  /// (WhatsApp, Messages, Mail, …). Reuses the same app-rating-url API
  /// as [_rateApp] — that URL *is* the public store listing, so it's
  /// the right thing to hand to a friend.
  Future<void> _shareApp() async {
    _showLoadingSnackbar('Preparing link…');

    final deviceType = Platform.isIOS ? 'ios' : 'android';
    final result = await sl<GetAppRatingUrlUseCase>()(deviceType);

    if (!mounted) return;

    result.fold(
      (failure) {
        debugPrint('[ShareApp] failure: $failure');
        CustomSnackbar.error(context, title: 'Error', message: failure.message);
      },
      (info) async {
        final url = info.ratingUrl;
        debugPrint('[ShareApp] deviceType=$deviceType ratingUrl=$url');
        if (url == null || url.isEmpty) {
          CustomSnackbar.error(
            context,
            title: 'Not Available',
            message: 'App link is not available right now.',
          );
          return;
        }

        final packageInfo = await PackageInfo.fromPlatform();
        if (!mounted) return;
        final appName = packageInfo.appName.trim().isEmpty
            ? 'our app'
            : packageInfo.appName.trim();

        // iPad presents the share sheet as a popover anchored to the
        // originating widget — without an origin rect it throws.
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        try {
          await SharePlus.instance.share(
            ShareParams(
              // Share text is plain text; *asterisks* are what messaging
              // apps (WhatsApp, Telegram) render as bold.
              text:
                  'Join me on *$appName*!\n'
                  'Learn anytime, anywhere with expert-led courses.\n'
                  'Download now: $url',
              subject: 'Join me on $appName',
              sharePositionOrigin: origin,
            ),
          );
        } catch (e) {
          debugPrint('[ShareApp] share error: $e');
          if (mounted) {
            CustomSnackbar.error(
              context,
              title: 'Cannot Share',
              message: 'Unable to open the share sheet.',
            );
          }
        }
      },
    );
  }

  /// Opens the edit-profile screen from the pencil on the profile card.
  ///
  /// The edit page reads the live profile straight from the global
  /// [ProfileCubit], so nothing is ferried through go_router's `extra:`.
  /// The guard is still needed though: the pencil is visible during the
  /// `updating` state too, and pushing a form with nothing loaded behind
  /// it would strand the learner on empty fields.
  void _openEditProfile() {
    final profile = context.read<ProfileCubit>().state.maybeWhen(
      loaded: (p) => p,
      updated: (p) => p,
      updating: (p) => p,
      orElse: () => null,
    );
    if (profile == null) {
      CustomSnackbar.warning(
        context,
        title: 'Hold on',
        message: 'Your profile is still loading.',
      );
      return;
    }
    context.push(AppRoutes.editProfile);
  }

  // ----------------------------------------------------------------
  // Ending the session
  // ----------------------------------------------------------------

  /// Tears down everything tied to the signed-in learner and sends them
  /// back to the entry screen. Shared by logout and account deletion,
  /// which differ only in what happens to the queued completions — see
  /// [deleted].
  ///
  /// Ordering matters throughout and is not incidental:
  ///   * the completion queue is handled first, while the access token
  ///     is still valid;
  ///   * the refresh-token family is revoked before the local wipe,
  ///     because revoking needs the refresh token that `clearToken` is
  ///     about to delete;
  ///   * neither step is allowed to block the exit — a learner who
  ///     cannot reach the backend must still get out of the session.
  Future<void> _endSession({bool deleted = false}) async {
    if (mounted) {
      // Drop cached profile so the next login doesn't briefly show the
      // previous user's data on Home.
      context.read<ProfileCubit>().reset();
    }
    final completions = sl<ContentCompletionService>();
    if (deleted) {
      // Nothing to drain into — the account is gone. See
      // ContentCompletionService.clearForAccountDeletion.
      await completions.clearForAccountDeletion();
    } else {
      // Drain, then wipe: the queue is device-scoped, so anything left
      // behind would be delivered under the next account's token.
      await completions.clearForLogout();
    }
    if (!deleted) {
      // Skipped after a deletion request: the server already revoked the
      // refresh-token family as part of filing it, so this would be a
      // round trip the learner waits through to redo work that is done.
      await sl<TokenRefreshService>().revokeSession();
    }
    await sl<SessionService>().clearToken();
    OrgCodeService.instance.clear();
    if (!mounted) return;
    // Show the Org Code gate only on iOS when ORG_ID is CRINZA — same
    // rule as the splash screen.
    final orgId = dotenv.env['ORG_ID'] ?? '';
    final isIosAndCrinza =
        !kIsWeb && Platform.isIOS && orgId.toUpperCase() == 'CRINZA';
    context.go(isIosAndCrinza ? AppRoutes.orgCode : AppRoutes.login);
  }

  /// Permanent account deletion, initiated and completed in the app.
  ///
  /// Required by App Store Review Guideline 5.1.1(v) — see
  /// [DeleteAccountUseCase] for why this can't be a link to the website.
  ///
  /// The local session is torn down **only after the server confirms**.
  /// Wiping first would leave a learner whose delete failed signed out
  /// of an account that still exists, with no token to retry on.
  Future<void> _handleDeleteAccount() async {
    // The dialog closes before the request goes out, which leaves the
    // tile tappable again while the delete is still in flight. Harmless
    // on the server if it's idempotent as specified, but the second
    // response would land after the first already tore the session
    // down — so don't start one.
    if (_deleting) return;

    final reason = await DeleteAccountDialog.show(context);
    if (reason == null || reason.isEmpty || !mounted) return;

    setState(() => _deleting = true);
    _showLoadingSnackbar('Submitting your request…');
    final result = await sl<DeleteAccountUseCase>()(reason: reason);
    if (!mounted) return;

    await result.fold(
      (failure) async {
        // Only the failure path releases the latch. On success the
        // session is torn down and this screen goes away, and leaving it
        // set is the cheapest guarantee that a second request can't be
        // filed in the gap — the endpoint is not idempotent, so a double
        // tap would put two rows in front of the back office.
        setState(() => _deleting = false);
        CustomSnackbar.error(
          context,
          title: 'Request not submitted',
          message: failure.message,
        );
      },
      (_) async {
        // The server revokes the refresh-token family, but the access
        // token this app already holds stays valid for seven days — so
        // signing out locally is what actually ends the session, not a
        // courtesy on top of it.
        await _endSession(deleted: true);
      },
    );
  }

  /// Shows a brief info snackbar while the API call is in-flight.
  void _showLoadingSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Screen().adaptDeviceScreenSize(context);
    final rh = ResponsiveHelper.of(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          width: double.infinity,
          // Don't set a fixed height — let the scroll view size itself.
          padding: EdgeInsets.symmetric(horizontal: rh.horizontalPadding),
          // Soft pink wash replacing the legacy DecorationImage —
          // built from `secondary` at low alpha so it carries the
          // brand-pink the design mock uses, without the overhead
          // of an image asset. Fades through to white around the
          // 55 % mark so the section cards underneath sit cleanly
          // on a neutral surface.
          decoration: BoxDecoration(
            // The pink wash reads as a soft blush on white, but over a
            // near-black page the same alphas turn to muddy plum. Dark
            // mode gets a much fainter indigo bloom that fades into the
            // scaffold instead, so the page stays calm and the cards
            // remain the brightest thing on it.
            gradient: AppColors.isDark
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.scaffoldLight,
                    ],
                    stops: const [0.0, 0.28, 0.62],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.28),
                      AppColors.secondary.withValues(alpha: 0.10),
                      AppColors.white,
                    ],
                    stops: const [0.0, 0.30, 0.55],
                  ),
          ),
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            backgroundColor: AppColors.white,
            displacement: 60,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: rh.isLargeScreen
                        ? Screen.width * 0.95
                        : rh.maxContentWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: Screen.getVerticalSize(65)),

                      // Profile Card Section
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          return state.maybeWhen(
                            // Every state that has a profile to show also
                            // has one to edit, so the pencil is wired in
                            // all three rather than only the settled one.
                            loaded: (profile) => PersonCardWidget(
                              profile: profile,
                              onEdit: _openEditProfile,
                            ),
                            updated: (profile) => PersonCardWidget(
                              profile: profile,
                              onEdit: _openEditProfile,
                            ),
                            updating: (current) => PersonCardWidget(
                              profile: current,
                              onEdit: _openEditProfile,
                            ),
                            error: (message) => ProfileCardError(
                              message: message,
                              onRetry: _onRefresh,
                            ),
                            orElse: () => const ProfileCardShimmer(),
                          );
                        },
                      ),
                      SizedBox(height: Screen.getVerticalSize(25)),

                      // MARK: Payments & Billing Section
                      PremiumSurface(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: Screen.getPadding(
                                vertical: 12,
                                horizontal: 15,
                              ),
                              child: Text(
                                "Payments & Billing",
                                style: AppTypography.bodyTextMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: Screen.getFontSizeCapped(14),
                                  color: AppColors.mutedTextPrimary,
                                ),
                              ),
                            ),
                            CustomProfileListTileWidget(
                              title: "Transaction History",
                              leadingIcon: AppImages.historyIcon,
                              onTap: () =>
                                  context.push(AppRoutes.transactionHistory),
                            ),
                            // Everything they signed up for, and the
                            // way back to a workshop pass. Sits above
                            // Certificates because it is the record a
                            // learner comes looking for soonest: on the
                            // morning of an event, not months later.
                            CustomProfileListTileWidget(
                              title: "My Bookings",
                              leadingIcon: AppImages.videoIcon,
                              onTap: () => context.push(AppRoutes.myBookings),
                            ),
                            // Completed courses + their certificates.
                            // Sits under Transaction History because it's
                            // the other "what have I got out of this
                            // account" record the learner comes looking for.
                            CustomProfileListTileWidget(
                              title: "Course Certificates",
                              leadingIcon: AppImages.verifiedIcon,
                              onTap: () => context.push(AppRoutes.certificates),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Screen.getVerticalSize(20)),

                      // The Account Settings section used to sit here.
                      // Both of its rows moved onto the profile card —
                      // Edit Profile became the pencil on the avatar, and
                      // Dark Mode the sun/moon badge beside the entity
                      // code — which left an empty titled panel behind.

                      // MARK: Help & Support Section
                      PremiumSurface(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: Screen.getPadding(
                                vertical: 12,
                                horizontal: 15,
                              ),
                              child: Text(
                                "Help & Support",
                                style: AppTypography.bodyTextMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: Screen.getFontSizeCapped(14),
                                  color: AppColors.mutedTextPrimary,
                                ),
                              ),
                            ),
                            // Contact for Support — calls the org-info API,
                            // then routes to WhatsApp or to in-app personal
                            // chat depending on the org's
                            // `allowWhatsappSupport` flag. One tile on
                            // purpose: an org runs one channel or the
                            // other, so a second entry would always be dead.
                            CustomProfileListTileWidget(
                              title: "Contact for Support",
                              leadingIcon: AppImages.callIcon,
                              onTap: _contactSupport,
                            ),
                            // TODO: Report an Issue — no flow defined yet, revisit later.
                            // const CustomProfileListTileWidget(
                            //   title: "Report an Issue",
                            //   leadingIcon: AppImages.issueIcon,
                            // ),
                            CustomProfileListTileWidget(
                              title: "Rate our App",
                              leadingIcon: AppImages.starIcon,
                              onTap: _rateApp,
                            ),
                            // Share App — reuses the app-rating-url store
                            // link and hands it to the native share sheet.
                            CustomProfileListTileWidget(
                              title: "Share App",
                              leadingIcon: AppImages.personIcon,
                              onTap: _shareApp,
                            ),
                            // Permanent account deletion. Last in the
                            // section on purpose: everything above it is
                            // reversible, and this is the one row a
                            // mis-tap can't be walked back from. Present
                            // on every platform — App Store guideline
                            // 5.1.1(v) mandates it and Play's data
                            // deletion policy expects it.
                            _DeleteAccountTile(onTap: _handleDeleteAccount),
                          ],
                        ),
                      ),
                      SizedBox(height: Screen.getVerticalSize(20)),

                      /// MARK: Legal
                      PremiumSurface(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: Screen.getPadding(
                                vertical: 12,
                                horizontal: 15,
                              ),
                              child: Text(
                                "Legal",
                                style: AppTypography.bodyTextMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: Screen.getFontSizeCapped(14),
                                  color: AppColors.mutedTextPrimary,
                                ),
                              ),
                            ),
                            // Terms & Conditions — calls API with termsAndCondition=true
                            CustomProfileListTileWidget(
                              title: "Terms & Conditions",
                              leadingIcon: AppImages.documentIcon,
                              onTap: _openTermsAndConditions,
                            ),
                            // Refund Policy — calls API with refundPolicy=true
                            CustomProfileListTileWidget(
                              title: "Refund Policy",
                              leadingIcon: AppImages.documentIcon,
                              onTap: _openRefundPolicy,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Screen.getVerticalSize(20)),

                      // MARK: Logout Button
                      LogoutButton(
                        onTap: () async {
                          final confirmed = await LogoutDialog.show(context);
                          if (confirmed != true) return;
                          await _endSession();
                        },
                      ),
                      SizedBox(height: Screen.getVerticalSize(10)),

                      const AppVersionText(),

                      SizedBox(height: Screen.getVerticalSize(25)),

                      Utils.defaultBottomSpace(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Delete Account" row.
///
/// Its own widget rather than a [CustomProfileListTileWidget] because it
/// needs to read as destructive — red ink, no trailing chevron — and
/// that tile paints its icon and title in the standard text colour and
/// always points onward to somewhere else. Red is the whole point here:
/// on a list where every other row is safe, this one has to look unlike
/// the others before it is tapped, not after.
class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.error.withValues(alpha: 0.1),
        highlightColor: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Padding(
          padding: Screen.getPadding(vertical: 12, horizontal: 15),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: Screen.getSize(20),
                color: AppColors.error,
              ),
              SizedBox(width: Screen.getHorizontalSize(15)),
              Expanded(
                child: Text(
                  'Delete Account',
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.error,
                    fontSize: Screen.getFontSizeCapped(14),
                  ),
                ),
              ),
              // The same chevron every other row carries, tinted to match
              // this one's ink. Its absence made this row look like a
              // dead-end label rather than something that opens.
              SizedBox.square(
                dimension: Screen.getSize(20),
                child: Image.asset(
                  AppImages.arrowRightIcon,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  // Flat monochrome PNG on transparent — tinting keeps
                  // the alpha and swaps the ink, same as the list tile.
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
