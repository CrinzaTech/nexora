import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/courses/presentation/widgets/draggable_fab.dart';
import 'package:nexora/features/courses/presentation/widgets/live_class_speed_dial.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';
import 'package:nexora/features/webinar/presentation/webinar_formatting.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_chat_panel.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_external_join.dart';
import 'package:nexora/features/webinar/presentation/widgets/webinar_hand_raise_fab.dart';

/// The webinar room, **in the app**.
///
/// The learner is signed in and already an account, so entering is one
/// call: A3 takes the seat, and the payload it returns puts them either
/// in the lobby or straight into the class. No phone screen, no form, no
/// OTP, no webview — that is the website's flow, for visitors who have no
/// account to be recognised by.
class WebinarRoomPage extends StatelessWidget {
  final String slug;
  final String roomId;
  final String title;

  /// Cover art carried over from the card, so the lobby has something to
  /// show while waiting rather than a bare countdown on grey.
  final String? thumbnailUrl;
  final String? educatorName;

  /// Whether this seat was free. Carried from the detail screen because
  /// the room's own payloads (A3/A4) say nothing about price — and a
  /// **paid** webinar never puts its meeting link on screen to be
  /// copied. See [WebinarExternalJoinBody].
  final bool isFree;

  /// What the detail payload said about the join mode. A workshop or a
  /// meeting opens straight onto its own screen; only a streamed webinar
  /// goes through the lobby.
  final bool isStream;

  const WebinarRoomPage({
    super.key,
    required this.slug,
    required this.roomId,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
    this.isFree = false,
    this.isStream = true,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<WebinarRoomCubit>()
        ..enter(slug: slug, roomId: roomId, isStream: isStream),
      child: _WebinarRoomView(
        slug: slug,
        title: title,
        thumbnailUrl: thumbnailUrl,
        educatorName: educatorName,
        isFree: isFree,
      ),
    );
  }
}

class _WebinarRoomView extends StatefulWidget {
  /// Carried down only so a workshop's venue card can offer the entry
  /// pass, which is keyed by slug.
  final String slug;
  final String title;
  final String? thumbnailUrl;
  final String? educatorName;
  final bool isFree;

  const _WebinarRoomView({
    required this.slug,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
    this.isFree = false,
  });

  @override
  State<_WebinarRoomView> createState() => _WebinarRoomViewState();
}

class _WebinarRoomViewState extends State<_WebinarRoomView> {
  BetterPlayerController? _player;

  /// Which URL the current controller was built for. Guards against
  /// rebuilding the player on every unrelated state emission (a chat
  /// message arrives every few seconds during a busy class).
  String? _currentUrl;
  bool _preparing = false;

  /// Whether the stream is currently quietened for a speaking turn.
  bool _ducked = false;

  /// Landscape only: the chat panel slides in over the video rather
  /// than docking beside it, so the stage keeps the full screen.
  bool _chatOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    // A webinar is watched, not tapped.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    final controller = _player;
    _player = null;
    _currentUrl = null;
    controller?.dispose(forceDispose: true);
  }

  Future<void> _syncPlayer(String hlsUrl) async {
    if (_preparing || _currentUrl == hlsUrl) return;
    _preparing = true;
    _disposePlayer();

    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        // We own the controller's lifecycle: the package otherwise
        // pauses on any visibility change (a dialog, a rotation) and a
        // live stream resumed from a paused position lands behind the
        // live edge.
        handleLifecycle: false,
        autoDispose: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enablePlaybackSpeed: false,
          enableSkips: false,
          showControlsOnInitialize: false,
          progressBarPlayedColor: AppColors.primary,
          progressBarHandleColor: AppColors.primary,
          progressBarBufferedColor: AppColors.primary.withValues(alpha: 0.3),
          progressBarBackgroundColor: AppColors.grey200,
        ),
      ),
    );
    _player = controller;
    _currentUrl = hlsUrl;
    controller.addEventsListener(_onPlayerEvent);

    try {
      await controller.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          hlsUrl,
          liveStream: true,
          // MUST be explicit. Left null the Android side infers the
          // content type from the filename's extension, misses on
          // "master_<hash>.m3u8", and builds a progressive source that
          // every extractor then rejects.
          videoFormat: BetterPlayerVideoFormat.hls,
          notificationConfiguration: BetterPlayerNotificationConfiguration(
            showNotification: true,
            title: widget.title,
            author: 'Webinar',
            notificationChannelName: 'Webinar',
            activityName: 'MainActivity',
          ),
          // Same segment maths as the live class: the publisher cuts
          // ~2s segments and the playlist window holds only a few, so
          // starting on less than a whole segment pins the player to the
          // live edge with no room to absorb a hiccup.
          bufferingConfiguration: const BetterPlayerBufferingConfiguration(
            minBufferMs: 4500,
            maxBufferMs: 12000,
            bufferForPlaybackMs: 2500,
            bufferForPlaybackAfterRebufferMs: 4000,
          ),
        ),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      // Required for raise-hand to work at all. Left alone, ExoPlayer and
      // AVPlayer hold exclusive audio focus and **pause** the moment the
      // WebRTC mic session takes it — the webinar would freeze for the
      // whole speaking turn. Mixing hands focus back to us; the stream is
      // quietened deliberately in [_applyDuck] instead.
      controller.setMixWithOthers(true);
      // Keep the duck level if the player was rebuilt mid-turn.
      await controller.setVolume(_ducked ? 0.2 : 1.0);
      setState(() {});
    } catch (_) {
      // A signed URL that expired between resolve and setup is the
      // common case — ask for a fresh one rather than showing a dead
      // player.
      if (mounted) context.read<WebinarRoomCubit>().refreshPlayback();
    } finally {
      _preparing = false;
    }
  }

  /// Quietens the stream while this attendee holds the mic, rather than
  /// pausing it: they still need to hear the host to answer, and an open
  /// mic beside a speaker at full volume is a feedback loop.
  Future<void> _applyDuck(bool duck) async {
    if (_ducked == duck) return;
    _ducked = duck;
    final controller = _player;
    await controller?.setVolume(duck ? 0.2 : 1.0);
    if (!duck) {
      // iOS's audio category is process-wide, and the WebRTC session
      // that just ended may have re-asserted its own over ours — ask for
      // mixing again so the stream isn't left holding exclusive focus.
      controller?.setMixWithOthers(true);
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      // Signed links are short-lived; a mid-session failure is usually
      // an expired one. Re-resolve instead of stranding the learner.
      context.read<WebinarRoomCubit>().refreshPlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WebinarRoomCubit, WebinarRoomState>(
      listenWhen: (p, c) =>
          p.hlsUrl != c.hlsUrl ||
          p.transientNotice != c.transientNotice ||
          p.handPhase != c.handPhase ||
          p.speakingUserId != c.speakingUserId,
      listener: (context, state) {
        final url = state.hlsUrl;
        if (url != null && state.phase == WebinarPhase.live) {
          _syncPlayer(url);
        }
        final myId = context.read<WebinarRoomCubit>().myId;
        // Duck on the local phase as well as the server's echo: the
        // attendee is audibly live from the moment the mic publishes,
        // which is before `nowSpeaking` comes back.
        _applyDuck(
          state.isSelfSpeaking(myId) ||
              state.handPhase == WebinarHandPhase.speaking,
        );
        final notice = state.transientNotice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
          context.read<WebinarRoomCubit>().clearNotice();
        }
      },
      builder: (context, state) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        return Scaffold(
          backgroundColor: AppColors.white,
          // Landscape gives the whole screen to the stage — an app bar
          // there costs a strip of height the 16:9 video needs.
          appBar: isLandscape
              ? null
              : CustomAppBar(title: widget.title, centerTitle: false),
          body: SafeArea(
            child: isLandscape
                ? _landscape(context, state)
                : _portrait(context, state),
          ),
        );
      },
    );
  }

  // ── Layout ───────────────────────────────────────────────────────

  /// Stage on top, chat filling the rest, with the hand-raise button
  /// floating over the chat.
  ///
  /// The button lives over the chat rather than over the video on
  /// purpose: the player's own controls (play/pause, fullscreen) occupy
  /// the video's bottom corners, and anything parked there fights them.
  Widget _portrait(BuildContext context, WebinarRoomState state) {
    if (state.phase == WebinarPhase.joining) {
      return const Center(child: CircularProgressIndicator());
    }

    // Zoom, Meet and workshops have no player and no chat, so there is
    // no stage to pin to the top and nothing to fill the rest with —
    // they get the whole screen for the one thing they do have.
    if (state.phase == WebinarPhase.external) {
      return WebinarExternalJoinBody(
        state: state,
        title: widget.title,
        thumbnailUrl: widget.thumbnailUrl,
        educatorName: widget.educatorName,
        isFree: widget.isFree,
        // A paid workshop issues an entry pass; the venue card is where
        // an attendee already goes looking for "what do I do on the
        // day", so the way to their ticket belongs beside it.
        slug: widget.slug,
      );
    }

    return Column(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _stage(context, state)),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: WebinarChatPanel(
                  myId: context.read<WebinarRoomCubit>().myId,
                ),
              ),
              if (_showHandRaise(state))
                Positioned.fill(
                  child: DraggableFab(
                    // Fixed logical pixels, not Screen.* — those scale
                    // against a portrait design frame, which collapses
                    // the bottom inset and drops the button onto the
                    // chat composer.
                    margin: const EdgeInsets.only(
                      left: 16,
                      top: 16,
                      right: 16,
                      bottom: 76,
                    ),
                    builder: (context, _) => WebinarHandRaiseFab(state: state),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Landscape hands the whole screen to the stage.
  ///
  /// The portrait column cannot survive here: a 16:9 box at the full
  /// width of a landscape screen is taller than the screen itself, so
  /// stacking chat under it overflows by whatever the difference is.
  /// Chat becomes an overlay panel instead, and the controls collapse
  /// into a speed dial that drags anywhere — parked over the video, it
  /// is always covering something.
  Widget _landscape(BuildContext context, WebinarRoomState state) {
    if (state.phase == WebinarPhase.joining) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.phase == WebinarPhase.external) {
      return WebinarExternalJoinBody(
        state: state,
        title: widget.title,
        thumbnailUrl: widget.thumbnailUrl,
        educatorName: widget.educatorName,
        isFree: widget.isFree,
        // A paid workshop issues an entry pass; the venue card is where
        // an attendee already goes looking for "what do I do on the
        // day", so the way to their ticket belongs beside it.
        slug: widget.slug,
      );
    }

    final size = MediaQuery.sizeOf(context);
    final panelWidth = (size.width * 0.42).clamp(260.0, 380.0);
    final myId = context.read<WebinarRoomCubit>().myId;

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _stage(context, state),
            ),
          ),
        ),

        // Always mounted, just slid off-screen: messages keep arriving
        // and the scroll position survives opening and closing.
        Positioned(
          top: 8,
          bottom: 8,
          right: 8,
          width: panelWidth,
          child: IgnorePointer(
            ignoring: !_chatOverlayOpen,
            child: AnimatedSlide(
              offset: _chatOverlayOpen ? Offset.zero : const Offset(1.1, 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _chatOverlayOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  elevation: 8,
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  clipBehavior: Clip.antiAlias,
                  child: WebinarChatPanel(myId: myId),
                ),
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: DraggableFab(
            margin: const EdgeInsets.all(16),
            builder: (context, dockedTop) => LiveClassSpeedDial(
              heroTag: 'webinar-speed-dial',
              // Parked up top, fanning upward would run off-screen.
              expandDown: dockedTop,
              children: [
                if (_showHandRaise(state))
                  WebinarHandRaiseFab(state: state, mini: true),
                FloatingActionButton.small(
                  heroTag: 'webinar-chat-toggle',
                  backgroundColor: _chatOverlayOpen
                      ? AppColors.error
                      : AppColors.primary,
                  foregroundColor: AppColors.alwaysWhite,
                  tooltip: _chatOverlayOpen ? 'Hide chat' : 'Show chat',
                  onPressed: () =>
                      setState(() => _chatOverlayOpen = !_chatOverlayOpen),
                  child: Icon(
                    _chatOverlayOpen
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Raising a hand only means anything while the class is running —
  /// there is nobody to hear it before the host starts or after they
  /// finish.
  bool _showHandRaise(WebinarRoomState state) =>
      state.phase == WebinarPhase.live;

  /// The 16:9 box, whatever is currently in it. Returned without its own
  /// [AspectRatio] so each layout can size it: pinned to the top in
  /// portrait, centred in the free space in landscape.
  Widget _stage(BuildContext context, WebinarRoomState state) {
    switch (state.phase) {
      case WebinarPhase.joining:
        return ColoredBox(
          color: AppColors.videoPlayerBgColor,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.alwaysWhite),
          ),
        );

      case WebinarPhase.error:
        return _StageError(
          message: state.errorMessage ?? 'Something went wrong.',
          canRetry: state.canRetry,
          paymentRequired: state.paymentRequired,
        );

      // Handled a layer up, where it gets the whole screen rather than a
      // 16:9 box. Reached only if a rebuild races the phase change.
      case WebinarPhase.external:
        return const _StageMessage(
          icon: Icons.open_in_new_rounded,
          text: 'This webinar happens elsewhere.',
        );

      // Ended and cancelled keep the chat: it is a transcript, and
      // someone arriving late deserves to read what was said rather than
      // hit a dead end.
      case WebinarPhase.ended:
        return const _StageMessage(
          icon: Icons.check_circle_outline_rounded,
          text: 'This webinar has finished.',
          detail: 'The chat is still here to read.',
        );

      case WebinarPhase.cancelled:
        return const _StageMessage(
          icon: Icons.event_busy_rounded,
          text: 'This webinar was cancelled.',
        );

      case WebinarPhase.lobby:
      case WebinarPhase.connecting:
        return _Lobby(
          state: state,
          title: widget.title,
          thumbnailUrl: widget.thumbnailUrl,
          educatorName: widget.educatorName,
        );

      case WebinarPhase.live:
        final player = _player;
        final myId = context.read<WebinarRoomCubit>().myId;
        final isMeSpeaking =
            state.isSelfSpeaking(myId) ||
            state.handPhase == WebinarHandPhase.speaking;

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.videoPlayerBgColor,
                child: player == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.alwaysWhite,
                        ),
                      )
                    : BetterPlayer(controller: player),
              ),
            ),
            // Who has the floor. Shown for this attendee too — "You're
            // live" is the one thing someone with an open mic most needs
            // to be sure of.
            if (isMeSpeaking || state.isOtherSpeaking(myId))
              Positioned(
                left: 12,
                bottom: 12,
                child: WebinarSpeakingChip(
                  name: state.speakingName ?? 'Someone',
                  isMe: isMeSpeaking,
                ),
              ),
          ],
        );
    }
  }
}

/// The waiting room. Not decoration — attendees arrive early, and this is
/// the only screen telling them they are in the right place and the class
/// has not started.
class _Lobby extends StatelessWidget {
  final WebinarRoomState state;
  final String title;
  final String? thumbnailUrl;
  final String? educatorName;

  const _Lobby({
    required this.state,
    required this.title,
    this.thumbnailUrl,
    this.educatorName,
  });

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final connecting = state.phase == WebinarPhase.connecting;

    // No AspectRatio of its own — the caller sizes the stage, which is
    // pinned to the top in portrait and centred in landscape.
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CustomNetworkImage(
              url: thumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: const SizedBox.shrink(),
            ),
          // Scrim: the cover is a photo and the copy on top has to stay
          // legible whatever it happens to be.
          Container(color: AppColors.black.withValues(alpha: 0.62)),
          Center(
            child: Padding(
              padding: Screen.getPadding(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (connecting) ...[
                    SizedBox(
                      width: Screen.getSize(22),
                      height: Screen.getSize(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.alwaysWhite,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(12)),
                    Text(
                      'Starting the stream…',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                        fontSize: Screen.getFontSize(15),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.schedule_rounded,
                      color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                      size: Screen.getSize(34),
                    ),
                    SizedBox(height: Screen.getVerticalSize(10)),
                    // `message` is written by the backend for exactly
                    // this spot — shown verbatim rather than re-worded
                    // per status, because the server knows which case
                    // it is and the client's guess would drift.
                    Text(
                      session?.message.isNotEmpty == true
                          ? session!.message
                          : 'Waiting for the host to start.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeMedium.copyWith(
                        color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                        fontSize: Screen.getFontSize(14),
                        height: 1.4,
                      ),
                    ),
                    if (session != null &&
                        session.timeUntilStart > Duration.zero) ...[
                      SizedBox(height: Screen.getVerticalSize(14)),
                      _LobbyCountdown(session: session),
                    ],
                  ],
                  SizedBox(height: Screen.getVerticalSize(14)),
                  // "You're in" — the reassurance the lobby exists for.
                  Container(
                    padding: Screen.getPadding(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: Screen.getSize(14),
                          color: AppColors.alwaysWhite,
                        ),
                        SizedBox(width: Screen.getHorizontalSize(6)),
                        Text(
                          "You're in. This will start automatically",
                          style: AppTypography.bodyTextSmallSemiBold.copyWith(
                            color: AppColors.alwaysWhite,
                            fontSize: Screen.getFontSizeCapped(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticks the lobby countdown down every second off the payload's own
/// `startsInSeconds` plus locally-elapsed time, so a wrong device clock
/// can't show a class as already finished or never starting.
class _LobbyCountdown extends StatefulWidget {
  final WebinarSessionState session;

  const _LobbyCountdown({required this.session});

  @override
  State<_LobbyCountdown> createState() => _LobbyCountdownState();
}

class _LobbyCountdownState extends State<_LobbyCountdown> {
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
  void didUpdateWidget(covariant _LobbyCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every poll hands back a fresh payload; count from that one.
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
    return Text(
      WebinarFormatting.countdown(_remaining),
      style: AppTypography.h4SemiBold.copyWith(
        color: AppColors.alwaysWhite,
        fontSize: Screen.getFontSizeCapped(24),
        letterSpacing: 1,
      ),
    );
  }
}

/// A short sentence filling the 16:9 stage — used for the ended and
/// cancelled phases, where the chat below stays readable.
class _StageMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? detail;

  const _StageMessage({required this.icon, required this.text, this.detail});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Center(
        child: Padding(
          padding: Screen.getPadding(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: Screen.getSize(34),
                color: AppColors.alwaysWhite.withValues(alpha: 0.85),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.alwaysWhite,
                  fontSize: Screen.getFontSize(15),
                ),
              ),
              if (detail != null) ...[
                SizedBox(height: Screen.getVerticalSize(6)),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.alwaysWhite.withValues(alpha: 0.75),
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The error phase, sized to the stage so the chat transcript below is
/// still reachable.
class _StageError extends StatelessWidget {
  final String message;
  final bool canRetry;

  /// A3 refused because this is a paid webinar they have not bought.
  /// The checkout lives on the detail screen, one pop away.
  final bool paymentRequired;

  const _StageError({
    required this.message,
    required this.canRetry,
    this.paymentRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.videoPlayerBgColor,
      child: Center(
        child: SingleChildScrollView(
          padding: Screen.getPadding(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: Screen.getSize(34),
                color: AppColors.alwaysWhite.withValues(alpha: 0.8),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                  fontSize: Screen.getFontSize(13),
                ),
              ),
              if (paymentRequired) ...[
                SizedBox(height: Screen.getVerticalSize(14)),
                SizedBox(
                  width: Screen.getHorizontalSize(180),
                  child: CustomActionButton(
                    isFormFilled: true,
                    name: 'Back to payment',
                    shouldAnimate: false,
                    // Not a retry: A3 will refuse identically until the
                    // payment verifies, and the screen that can take it
                    // is the one they came from. Opened by a deep link
                    // there is nothing behind this route, so that case
                    // goes to the detail screen directly.
                    onTap: (startLoading, stopLoading, btnState) {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      final slug = context.read<WebinarRoomCubit>().slug;
                      context.go(
                        '${AppRoutes.webinarDetail}'
                        '?slug=${Uri.encodeComponent(slug)}',
                      );
                    },
                  ),
                ),
              ] else if (canRetry) ...[
                SizedBox(height: Screen.getVerticalSize(14)),
                SizedBox(
                  width: Screen.getHorizontalSize(160),
                  child: CustomActionButton(
                    isFormFilled: true,
                    name: 'Retry',
                    shouldAnimate: false,
                    onTap: (startLoading, stopLoading, btnState) {
                      startLoading();
                      context.read<WebinarRoomCubit>().retry().whenComplete(
                        () => stopLoading(),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
