import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_cover.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';

/// The room screen for a webinar we do not stream: a Zoom or Meet
/// meeting, or a workshop with an address.
///
/// **A meeting and a venue are not the same thing, and this screen says
/// so.** A meeting link is opened at a moment; a venue is somewhere to
/// go. So the meeting gets one button that leaves the app, and the
/// workshop gets a card the attendee can read, screenshot, copy and come
/// back to on the day — the URL is never auto-launched.
///
/// Neither has a lobby. `canWatch` never flips for either, so a
/// countdown-and-wait screen here would be a promise that never
/// resolves; what they are waiting for is a calendar entry, not a
/// stream starting.
class WebinarExternalJoinBody extends StatelessWidget {
  final WebinarRoomState state;
  final String title;
  final String? thumbnailUrl;
  final String? educatorName;

  /// Whether this seat was free.
  ///
  /// A **paid** webinar never puts its meeting link on screen: the
  /// button opens it and nothing else does. A venue is exempt — an
  /// address has to be readable to be walked to.
  final bool isFree;

  const WebinarExternalJoinBody({
    super.key,
    required this.state,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
    this.isFree = false,
  });

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isVenue = session.isInPerson;

    return ListView(
      padding: Screen.getPadding(horizontal: 20, vertical: 16),
      children: [
        _Cover(thumbnailUrl: thumbnailUrl, session: session),
        SizedBox(height: Screen.getVerticalSize(16)),

        Text(
          title,
          style: AppTypography.h4SemiBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: Screen.getFontSizeCapped(20),
            height: 1.25,
          ),
        ),
        if (educatorName != null && educatorName!.isNotEmpty) ...[
          SizedBox(height: Screen.getVerticalSize(6)),
          Text(
            educatorName!,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(13),
            ),
          ),
        ],

        SizedBox(height: Screen.getVerticalSize(14)),
        const _RegisteredNotice(),

        SizedBox(height: Screen.getVerticalSize(12)),
        // Written by the backend for exactly this spot — "You are
        // registered. The meeting opens in Zoom at the scheduled time.",
        // "The venue location is below." Shown verbatim.
        if (session.message.isNotEmpty)
          Text(
            session.message,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: Screen.getFontSize(14),
              height: 1.5,
            ),
          ),

        if (session.timeUntilStart > Duration.zero) ...[
          SizedBox(height: Screen.getVerticalSize(14)),
          _StartsIn(session: session),
        ],

        SizedBox(height: Screen.getVerticalSize(18)),
        if (!session.hasExternalUrl)
          // The link is released to registered attendees only, and goes
          // null once the event is cancelled or over — so its absence is
          // worth saying plainly rather than showing a dead button.
          _Notice(
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
            text: isVenue
                ? 'The host has not shared the venue yet. It will appear '
                      'here as soon as they do.'
                : 'The host has not shared the meeting link yet. It will '
                      'appear here as soon as they do.',
          )
        else if (isVenue)
          _VenueCard(session: session)
        else
          _MeetingCard(session: session, isFree: isFree),

        SizedBox(height: Screen.getVerticalSize(24)),
      ],
    );
  }
}

/// Cover art with the platform's own name on it — a Zoom badge is the
/// fastest way to say "this does not happen in the app" before any of
/// the copy is read.
class _Cover extends StatelessWidget {
  final String? thumbnailUrl;
  final WebinarSessionState session;

  const _Cover({required this.thumbnailUrl, required this.session});

  @override
  Widget build(BuildContext context) {
    final hasCover = thumbnailUrl?.isNotEmpty ?? false;

    return Stack(
      children: [
        GestureDetector(
          onTap: hasCover ? () => showWebinarCover(context, thumbnailUrl) : null,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              // Whole image, never a crop — see [WebinarCoverImage].
              child: WebinarCoverImage(
                url: thumbnailUrl,
                fallback: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Icon(
                    session.isInPerson
                        ? Icons.location_on_outlined
                        : Icons.videocam_outlined,
                    color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                    size: Screen.getSize(48),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: WebinarPlatformBadge(
            platformName: session.platformName,
            joinMode: session.joinMode,
          ),
        ),
        if (hasCover)
          const Positioned(
            right: 12,
            bottom: 12,
            child: WebinarCoverExpandButton(),
          ),
      ],
    );
  }
}

/// "Zoom" · "Google Meet" · "Workshop". The label comes from the server
/// (`platformName`) so a platform added later names itself without a
/// client release; only the icon is chosen locally, from [joinMode].
class WebinarPlatformBadge extends StatelessWidget {
  final String platformName;
  final WebinarJoinMode joinMode;
  final bool compact;

  const WebinarPlatformBadge({
    super.key,
    required this.platformName,
    required this.joinMode,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (joinMode) {
      WebinarJoinMode.meeting => Icons.videocam_rounded,
      WebinarJoinMode.location => Icons.location_on_rounded,
      WebinarJoinMode.stream => Icons.podcasts_rounded,
    };

    return Container(
      padding: Screen.getPadding(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Screen.getSize(compact ? 10 : 13),
            color: AppColors.alwaysWhite,
          ),
          SizedBox(width: Screen.getHorizontalSize(4)),
          Text(
            platformName,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: Screen.getFontSizeCapped(compact ? 8 : 10),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoom / Meet — one button, and it leaves the app.
class _MeetingCard extends StatelessWidget {
  final WebinarSessionState session;

  /// A paid seat keeps its link off the screen — see
  /// [WebinarExternalJoinBody.isFree].
  final bool isFree;

  const _MeetingCard({required this.session, required this.isFree});

  @override
  Widget build(BuildContext context) {
    final url = session.externalJoinUrl!;

    // Unlocks itself on the tick the start time passes, so an attendee
    // sitting on this screen waiting for the class doesn't have to
    // reload to get in.
    return _JoinWindow(
      session: session,
      builder: (context, isOpen) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomActionButton(
            isFormFilled: isOpen,
            name: 'Join on ${session.platformName}',
            shouldAnimate: false,
            leading: Padding(
              padding: EdgeInsets.only(right: Screen.getHorizontalSize(8)),
              child: Icon(
                isOpen ? Icons.open_in_new_rounded : Icons.lock_outline_rounded,
                color: AppColors.alwaysWhite,
                size: Screen.getSize(18),
              ),
            ),
            onTap: (startLoading, stopLoading, btnState) {
              if (!isOpen) return;
              _openExternally(context, url);
            },
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          // The link itself is held back with the button. Showing it —
          // selectable, with a Copy button beside it — while the button
          // is disabled would make the lock decorative.
          //
          // On a paid webinar it stays off the screen even once the room
          // is open: a meeting URL sitting there next to a Copy button
          // is a seat somebody paid for, one paste away from anybody who
          // didn't. Leaving *through* the link is the point; leaving with
          // a copy of it isn't.
          if (isOpen) ...[
            if (isFree) ...[
              _LinkRow(url: url, label: 'Meeting link'),
              SizedBox(height: Screen.getVerticalSize(10)),
            ],
            Text(
              isFree
                  ? 'This opens in ${session.platformName}. Keep this link — '
                        'you can come back here any time during the session.'
                  : 'This opens in ${session.platformName}. Come back to this '
                        'screen any time during the session to rejoin.',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(12),
                height: 1.4,
              ),
            ),
          ] else
            _Notice(
              icon: Icons.lock_clock_rounded,
              color: AppColors.primary,
              text:
                  'The ${session.platformName} link opens when the webinar '
                  'starts. Come back here then — this page unlocks on its '
                  'own.',
            ),
        ],
      ),
    );
  }
}

/// Rebuilds its child as the wait runs out, and hands it whether the
/// meeting link may be opened yet.
///
/// The countdown is local: [WebinarSessionState.timeUntilStart] measures
/// elapsed time since the payload arrived, so nothing here needs the
/// room to keep polling — which matters, because a meeting has nothing
/// to poll *for* and the room stops as soon as it lands on this screen.
class _JoinWindow extends StatefulWidget {
  final WebinarSessionState session;
  final Widget Function(BuildContext context, bool isOpen) builder;

  const _JoinWindow({required this.session, required this.builder});

  @override
  State<_JoinWindow> createState() => _JoinWindowState();
}

class _JoinWindowState extends State<_JoinWindow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _JoinWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh payload restarts the count against its own `receivedAt`.
    if (oldWidget.session != widget.session) _schedule();
  }

  /// Ticks once a second inside the last minute, where the unlock
  /// actually lands, and once a minute before that — a webinar two days
  /// out does not need 172,800 rebuilds to notice it hasn't started.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final remaining = widget.session.timeUntilStart;
    if (remaining <= Duration.zero) return;

    final interval = remaining.inMinutes >= 1
        ? const Duration(seconds: 30)
        : const Duration(seconds: 1);
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {});
      // Re-schedule as the wait shortens, and stop once it's open.
      final left = widget.session.timeUntilStart;
      if (left <= Duration.zero || left.inMinutes < 1) _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.session.isJoinWindowOpen);
}

/// A workshop — a place, on a day.
///
/// Deliberately not auto-launched and deliberately not a bare button:
/// the attendee needs the address in front of them, and will most likely
/// want it again on the morning of the workshop rather than at the
/// moment they registered.
class _VenueCard extends StatelessWidget {
  final WebinarSessionState session;

  const _VenueCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final url = session.externalJoinUrl!;

    return Container(
      padding: Screen.getPadding(all: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: AppDecorations.cardBorder(
          lightColor: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: Screen.getSize(18),
                color: AppColors.primary,
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                'Venue',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSize(14),
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          _LinkRow(url: url, label: 'Location'),
          SizedBox(height: Screen.getVerticalSize(12)),
          CustomActionButton(
            isFormFilled: true,
            name: 'Open in Maps',
            shouldAnimate: false,
            leading: Padding(
              padding: EdgeInsets.only(right: Screen.getHorizontalSize(8)),
              child: Icon(
                Icons.map_outlined,
                color: AppColors.alwaysWhite,
                size: Screen.getSize(18),
              ),
            ),
            onTap: (startLoading, stopLoading, btnState) =>
                _openExternally(context, url),
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          Text(
            'This is an in-person workshop. Save the location — you will '
            'need it on the day.',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(12),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The URL itself, with a copy button — the one thing an attendee is
/// likely to want somewhere other than this screen (a calendar entry, a
/// message to whoever is driving them there).
class _LinkRow extends StatelessWidget {
  final String url;
  final String label;

  const _LinkRow({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyTextXtraSmallBold.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontSize: Screen.getFontSizeCapped(10),
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(2)),
                Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Link copied.')));
            },
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            child: Padding(
              padding: Screen.getPadding(all: 6),
              child: Icon(
                Icons.copy_rounded,
                size: Screen.getSize(18),
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both modes leave the app entirely — `externalApplication` so Zoom,
/// Meet or Maps handles it if it is installed, rather than an in-app
/// webview that would ask the attendee to sign in to Zoom inside a
/// browser that forgets them.
Future<void> _openExternally(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text("Couldn't open that link on this device.")),
    );
}

class _RegisteredNotice extends StatelessWidget {
  const _RegisteredNotice();

  @override
  Widget build(BuildContext context) {
    return _Notice(
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      text: "You're registered. Your place is saved.",
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

/// Counts off the payload's own `startsInSeconds` plus locally-elapsed
/// time, so a wrong device clock cannot show a workshop as over.
class _StartsIn extends StatefulWidget {
  final WebinarSessionState session;

  const _StartsIn({required this.session});

  @override
  State<_StartsIn> createState() => _StartsInState();
}

class _StartsInState extends State<_StartsIn> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.session.timeUntilStart;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.session.timeUntilStart);
    });
  }

  @override
  void didUpdateWidget(covariant _StartsIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _remaining = widget.session.timeUntilStart;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: Screen.getSize(16),
          color: AppColors.primary,
        ),
        SizedBox(width: Screen.getHorizontalSize(6)),
        Text(
          'Starts in ${WebinarFormatting.countdown(_remaining)}',
          style: AppTypography.bodyTextLargeSemiBold.copyWith(
            color: AppColors.primary,
            fontSize: Screen.getFontSize(14),
          ),
        ),
      ],
    );
  }
}
