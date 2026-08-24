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
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/download_workshop_pass_usecase.dart';
import 'package:nexora/features/workshop_pass/presentation/bloc/workshop_pass_cubit.dart';
import 'package:nexora/features/workshop_pass/presentation/widgets/workshop_pass_card.dart';
import 'package:nexora/features/workshop_pass/presentation/workshop_pass_brightness.dart';

/// The attendee's entry pass for a paid in-person workshop.
///
/// **This screen is held up at a door**, which decides everything about
/// it: the ticket is the *only* thing on it, the screen goes to full
/// brightness while it is open, and the pass number sits in a thin strip
/// under the app bar for when a scan fails.
///
/// Same shape as the certificate preview, and for the same reason. An
/// earlier version stacked the title, date, venue and attendee in cards
/// beneath the ticket — but the artwork already prints every one of
/// them, so it said each thing twice and left the pass itself with a
/// third of the screen. Directions and Save moved into the app bar:
/// occasional actions, and not what anyone opened this for.
///
/// It also has to work in a queue with no signal, so a cached copy is
/// shown the instant there is one and the fetch runs behind it. That is
/// safe: the pass number and QR are frozen server-side at first issue,
/// so a cached pass and a fresh one are the same ticket.
class WorkshopPassPage extends StatelessWidget {
  final String slug;

  /// Carried from whichever screen opened this, purely so the header has
  /// something to say while the first fetch is in flight.
  final String? workshopTitle;

  const WorkshopPassPage({super.key, required this.slug, this.workshopTitle});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<WorkshopPassCubit>()..load(slug),
      child: _WorkshopPassView(slug: slug, workshopTitle: workshopTitle),
    );
  }
}

class _WorkshopPassView extends StatefulWidget {
  final String slug;
  final String? workshopTitle;

  const _WorkshopPassView({required this.slug, this.workshopTitle});

  @override
  State<_WorkshopPassView> createState() => _WorkshopPassViewState();
}

class _WorkshopPassViewState extends State<_WorkshopPassView> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Raised for the whole screen rather than only once the pass lands:
    // the ramp is not instant on every device, and somebody already at
    // the door should not have to wait for a fetch before their screen
    // is readable.
    WorkshopPassBrightness.boost();
  }

  @override
  void dispose() {
    WorkshopPassBrightness.restore();
    super.dispose();
  }

  /// The venue, opened from the app bar.
  ///
  /// The organiser stores a maps URL and the artwork prints the readable
  /// half of it, so there is nothing to gain from repeating the raw link
  /// on screen — only somewhere to go.
  Future<void> _openVenue(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      CustomSnackbar.error(
        context,
        title: 'Cannot open maps',
        message: 'No app on this device could open the venue link.',
      );
    }
  }

  /// Saving is **secondary**. The pass works on screen; this is for
  /// someone who wants it printed, in their gallery, or forwarded to
  /// whoever is driving them there.
  ///
  /// The spinner is on the button, not the page, so the ticket stays
  /// readable while the PDF builds — which matters if they are already
  /// in the queue.
  Future<void> _save(WorkshopPass pass) async {
    if (_saving) return;
    setState(() => _saving = true);

    final result = await sl<DownloadWorkshopPassUseCase>()(
      slug: widget.slug,
      pass: pass,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (failure) => CustomSnackbar.error(
        context,
        title: 'Could not save the pass',
        // The server writes these for attendees; shown as they came.
        message: failure.message,
      ),
      // Opening it straight away is what "Save" is expected to do — a
      // snackbar saying "saved to documents" leaves them hunting for a
      // file manager.
      (downloaded) => context.push(AppRoutes.workshopPassPdf, extra: downloaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: 'Entry pass',
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
        // Directions and Save live up here rather than as buttons under
        // the pass. Both are things you do occasionally; the pass is the
        // thing you came for, and it should not have to share the screen
        // with them.
        actions: [
          BlocBuilder<WorkshopPassCubit, WorkshopPassState>(
            builder: (context, state) {
              final pass = state.maybeWhen(
                loaded: (pass, _) => pass,
                orElse: () => null,
              );
              if (pass == null) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pass.hasVenueLink)
                    IconButton(
                      tooltip: 'Directions',
                      icon: Icon(Icons.map_outlined, color: AppColors.white),
                      onPressed: () => _openVenue(pass.venueUrl!),
                    ),
                  IconButton(
                    tooltip: 'Save as PDF',
                    icon: _saving
                        ? SizedBox(
                            width: Screen.getSize(18),
                            height: Screen.getSize(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Icon(
                            Icons.download_rounded,
                            color: AppColors.white,
                          ),
                    onPressed: _saving ? null : () => _save(pass),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<WorkshopPassCubit, WorkshopPassState>(
          builder: (context, state) {
            return state.maybeWhen(
              loaded: (pass, fromCache) => _PassBody(pass: pass),
              needsPurchase: (message) => _NeedsPurchase(
                message: message,
                slug: widget.slug,
                workshopTitle: widget.workshopTitle,
              ),
              unavailable: (message) => _Refusal(
                icon: Icons.info_outline_rounded,
                color: AppColors.warning,
                title: 'No pass for this one',
                message: message,
              ),
              error: (message) => _Refusal(
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                title: 'Could not load your pass',
                message: message,
                onRetry: () =>
                    context.read<WorkshopPassCubit>().load(widget.slug),
              ),
              orElse: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The pass, full screen and nothing else.
///
/// Everything that used to sit under the ticket — the workshop title,
/// the date, the venue, the attendee — is **already printed on the
/// artwork**. Repeating it in cards below said the same thing twice and
/// pushed the one thing that matters into a third of the screen.
///
/// So this is the certificate treatment: a thin number strip and the
/// document itself, as large as the screen allows.
class _PassBody extends StatelessWidget {
  final WorkshopPass pass;

  const _PassBody({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The number is printed inside the artwork too, but small — and
        // the moment it matters is the one where the QR would not scan
        // and somebody at a door is asking for it out loud.
        if (pass.passNo.isNotEmpty) _PassNumberStrip(passNo: pass.passNo),
        Expanded(
          child: Padding(
            padding: Screen.getPadding(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                if (pass.isCheckedIn) ...[
                  const _CheckedInChip(),
                  SizedBox(height: Screen.getVerticalSize(14)),
                ],
                // Expanded, not a scroll view: the card measures itself
                // and shrinks to fit whatever is left, so the whole pass
                // is on screen at once. Scrolling to find the rest of a
                // ticket is not something to do at a door.
                Expanded(
                  child: pass.hasArtwork
                      // Dimmed once they are inside — a used pass that
                      // still looks live is how somebody tries to hand
                      // it to a second person at the same door.
                      ? Opacity(
                          opacity: pass.isCheckedIn ? 0.45 : 1,
                          child: WorkshopPassCard(pass: pass),
                        )
                      // The fallback is plain widgets with no measurable
                      // document behind them, so it keeps a scroll view
                      // for the case where a small screen cannot hold it.
                      : SingleChildScrollView(
                          child: Opacity(
                            opacity: pass.isCheckedIn ? 0.45 : 1,
                            child: _ArtworkFallback(pass: pass),
                          ),
                        ),
                ),
                if (pass.hasArtwork) ...[
                  SizedBox(height: Screen.getVerticalSize(10)),
                  // Pinch zoom leaves no trace on screen, so it needs
                  // one line to say it is there. Small print, because
                  // the pass works perfectly well without it.
                  Text(
                    'Pinch to zoom',
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                      fontSize: Screen.getFontSize(11),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The number under the app bar, in the same place and the same weight
/// the certificate preview puts its certificate number.
class _PassNumberStrip extends StatelessWidget {
  final String passNo;

  const _PassNumberStrip({required this.passNo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: passNo));
        if (!context.mounted) return;
        CustomSnackbar.success(
          context,
          title: 'Copied',
          message: 'Pass number copied.',
        );
      },
      child: Container(
        width: double.infinity,
        color: AppColors.videoPlayerBgColor,
        padding: Screen.getPadding(horizontal: 20, bottom: 12),
        child: Text(
          'Pass No. $passNo',
          textAlign: TextAlign.center,
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.white.withValues(alpha: 0.75),
            fontSize: Screen.getFontSize(12),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// Checked in — a chip above the pass rather than a full-width banner,
/// so it says its piece without taking a block of the screen.
class _CheckedInChip extends StatelessWidget {
  const _CheckedInChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: Screen.getSize(15),
            color: AppColors.success,
          ),
          SizedBox(width: Screen.getHorizontalSize(6)),
          Text(
            "You're checked in",
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.success,
              fontSize: Screen.getFontSize(12),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is left when the server could not build the artwork.
///
/// Deliberately **not** a hand-built replica of the ticket — the whole
/// reason the design lives in one shared partial is that a native copy
/// drifts. This is the QR and the number, which is everything a door
/// actually needs.
class _ArtworkFallback extends StatelessWidget {
  final WorkshopPass pass;

  const _ArtworkFallback({required this.pass});

  @override
  Widget build(BuildContext context) {
    final qr = pass.qrBytes;

    return Container(
      padding: Screen.getPadding(all: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          if (qr != null)
            Image.memory(qr, width: Screen.getSize(180), height: Screen.getSize(180))
          else
            Icon(
              Icons.confirmation_number_outlined,
              size: Screen.getSize(56),
              color: AppColors.grey300,
            ),
          SizedBox(height: Screen.getVerticalSize(12)),
          Text(
            qr != null
                ? 'Show this code at the door.'
                : 'Your pass artwork could not be loaded. Give the pass '
                      'number below to the staff at the door.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(13),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// `402` — the state *before* buying, not a failure.
///
/// Reached when the app's own purchase state was stale. The server is
/// right and the app is wrong, so this routes back to the workshop
/// rather than apologising.
class _NeedsPurchase extends StatelessWidget {
  final String message;
  final String slug;
  final String? workshopTitle;

  const _NeedsPurchase({
    required this.message,
    required this.slug,
    this.workshopTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: Screen.getSize(60),
              color: AppColors.primary,
            ),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              workshopTitle ?? 'Your pass is waiting',
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
                height: 1.45,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(20)),
            CustomActionButton(
              isFormFilled: true,
              name: 'Go to the workshop',
              buttonWidth: Screen.getHorizontalSize(220),
              shouldAnimate: false,
              onTap: (startLoading, stopLoading, btnState) {
                // Almost always reached from the workshop screen itself,
                // so going back is both cheaper and less disorienting
                // than stacking a second copy of it on top. The push is
                // the fallback for a deep link with nothing behind it.
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.pushReplacement(
                  '${AppRoutes.webinarDetail}?slug=${Uri.encodeComponent(slug)}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Refusal extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _Refusal({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Screen.getSize(60), color: color),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(16),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),
            // The server's own sentence — these are written for
            // attendees and say what happens next, so they are never
            // re-worded here.
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: Screen.getVerticalSize(20)),
              CustomActionButton(
                isFormFilled: true,
                name: 'Retry',
                buttonWidth: Screen.getHorizontalSize(160),
                shouldAnimate: false,
                onTap: (startLoading, stopLoading, btnState) => onRetry!(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
