import 'dart:async';
import 'dart:convert';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Default jump for one tap on a skip control.
const Duration kDefaultSeekStep = Duration(seconds: 10);

/// Default preferred caption language.
const String kDefaultCaptionLanguage = 'en';

/// Default lifetime of the landscape controls after the last touch.
const Duration kDefaultLandscapeControlsTimeout = Duration(seconds: 3);

/// Surface / hairline / text tints for the custom chrome.
///
/// The lecture page is always dark (`AppColors.videoPlayerBgColor`) no matter
/// which theme the app is in, so these are built from `alwaysWhite` rather
/// than the theme-flipping `white` / `grey*` getters — otherwise the controls
/// invert to near-black chips on a navy background in light mode.
final Color _kSurface = AppColors.alwaysWhite.withValues(alpha: 0.08);
final Color _kSurfaceStrong = AppColors.alwaysWhite.withValues(alpha: 0.12);
final Color _kHairline = AppColors.alwaysWhite.withValues(alpha: 0.16);
final Color _kOnSurface = AppColors.alwaysWhite.withValues(alpha: 0.70);
final Color _kOnSurfaceMuted = AppColors.alwaysWhite.withValues(alpha: 0.45);
final Color _kOnSurfaceDisabled = AppColors.alwaysWhite.withValues(alpha: 0.28);

/// Carries the landscape skip controls over arbitrary video.
///
/// Those controls have no fill or border to sit on — a white glyph alone
/// disappears against a bright frame, so it gets a soft drop shadow the way
/// every over-video control does.
const List<Shadow> _kOverVideoShadow = [
  Shadow(color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 1)),
];

/// A design-system text style pinned to its Figma baseline size.
///
/// Every `AppTypography` style sizes itself through `Screen.getFontSize`,
/// which scales against the **raw** device width over a 360-wide *portrait*
/// frame. In landscape that width is the long edge, so the factor jumps to
/// ~2.5x and a 10px label renders at ~25px — enough to burst the 52px skip
/// buttons ("RenderFlex overflowed by 13 pixels"). `Screen.getScaleFactor()`
/// was already made orientation-safe for `getSize`; `getFontSize` never was.
///
/// This player's chrome is fixed-pixel by construction (52-high skip buttons,
/// a 48-square gear) and renders over the video in both orientations, so its
/// labels have to be fixed-pixel too. Pinning the size keeps the family,
/// weight and line-height ratio from the design system without inheriting
/// that scaling. OS-level text scaling still applies — the controls use
/// `minHeight` rather than a fixed height so they grow instead of overflowing.
TextStyle _chrome(TextStyle base, double fontSize, Color color) =>
    base.copyWith(fontSize: fontSize, color: color);

/// The actions offered by the player's settings menu.
enum PlayerSetting { subtitles, subtitleLanguage }

/// One caption track the loaded video actually offers.
class CaptionTrack {
  const CaptionTrack({required this.code, required this.name});

  final String code;
  final String name;
}

/// A YouTube lecture player built on the **official IFrame player API**
/// (`youtube_player_flutter`), with custom skip / caption / settings controls
/// that survive landscape fullscreen.
///
/// This replaces the previous `pod_player` + `youtube_explode_dart` path,
/// which resolved and played YouTube's raw stream URLs directly. That
/// bypasses the YouTube player entirely (no ads, no branding) and is a
/// Developer Policy violation; this widget renders YouTube's own player, so
/// playback is compliant.
///
/// Sizes itself to its content in portrait, so it can be dropped into a
/// Column, ListView or anywhere else. In landscape the underlying
/// [YoutubePlayerBuilder] takes over the whole screen — the host must hide
/// its app bar and unlock device orientation. See `PLAYER_INTEGRATION.md`.
class CustomYoutubePlayer extends StatefulWidget {
  const CustomYoutubePlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.captionsEnabled = true,
    this.captionLanguage = kDefaultCaptionLanguage,
    this.seekStep = kDefaultSeekStep,
    this.landscapeControlsTimeout = kDefaultLandscapeControlsTimeout,
    this.onReady,
    this.onError,
    this.onProgress,
  });

  /// Full YouTube URL or a bare 11-character video id.
  ///
  /// Accepts `youtu.be/…`, `youtube.com/watch?v=…`, `/shorts/…` and
  /// `/embed/…`. Changing it loads the new video in place — which is what
  /// makes this usable with an id fetched from your API.
  final String videoUrl;

  final bool autoPlay;

  /// Whether captions start on. Mirrored into the player's `cc_load_policy`.
  final bool captionsEnabled;

  /// Preferred caption language. Falls back to the video's first track when
  /// the video does not carry this language.
  final String captionLanguage;

  /// How far one tap on the skip controls jumps.
  final Duration seekStep;

  /// How long the landscape controls stay up after the last touch.
  final Duration landscapeControlsTimeout;

  final VoidCallback? onReady;

  /// Called with the YouTube error code when a video fails to load — 150/101
  /// mean the owner disabled embedding, which is common enough to handle.
  final void Function(int errorCode)? onError;

  /// Fired on every value tick with the current position and the video's
  /// total duration. Used by the lecture page to drive the 75% content
  /// completion POST. `duration` is `Duration.zero` until metadata arrives.
  final void Function(Duration position, Duration duration)? onProgress;

  @override
  State<CustomYoutubePlayer> createState() => _CustomYoutubePlayerState();
}

class _CustomYoutubePlayerState extends State<CustomYoutubePlayer>
    with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _videoId;
  int? _reportedErrorCode;
  late bool _captionsEnabled;
  List<CaptionTrack> _captionTracks = const [];
  String? _captionLanguage;
  bool _captionTracksRequested = false;
  Timer? _landscapeControlsTimer;
  bool _landscapeControlsVisible = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();

    _captionsEnabled = widget.captionsEnabled;
    _captionLanguage = widget.captionLanguage;

    // `initialVideoId` needs the bare 11-char id, not a full URL — otherwise
    // the player spins on "loading" forever. A null here means the string we
    // were handed is not a YouTube link at all, which is a real possibility
    // when the value arrives from an API.
    _videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    _controller = YoutubePlayerController(
      initialVideoId: _videoId ?? '',
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        disableDragSeek: false,
        loop: false,
        enableCaption: widget.captionsEnabled,
        captionLanguage: widget.captionLanguage,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _controller.addListener(_onPlayerValueChanged);
  }

  @override
  void didUpdateWidget(CustomYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl) return;

    final next = YoutubePlayer.convertUrlToId(widget.videoUrl);
    setState(() {
      _videoId = next;
      // Caption state belongs to the old video; every field has to go or the
      // language menu will offer tracks the new video does not have.
      _captionTracks = const [];
      _captionTracksRequested = false;
      _captionLanguage = widget.captionLanguage;
      _captionsEnabled = widget.captionsEnabled;
      _reportedErrorCode = null;
    });
    if (next != null) _controller.load(next);
  }

  /// YouTube only fills in the caption tracklist once the captions module has
  /// actually loaded, which does not happen until playback has begun — so the
  /// list is fetched on first frame played rather than on ready.
  void _onPlayerValueChanged() {
    final value = _controller.value;

    // Report each distinct error once. 101/150 mean the uploader disabled
    // embedding, which no amount of retrying will fix.
    if (value.hasError && value.errorCode != _reportedErrorCode) {
      _reportedErrorCode = value.errorCode;
      widget.onError?.call(value.errorCode);
    }

    widget.onProgress?.call(value.position, value.metaData.duration);

    if (_captionTracksRequested) return;
    if (!value.isReady || value.position <= Duration.zero) return;
    _captionTracksRequested = true;
    _loadCaptionTracks();
  }

  Future<void> _loadCaptionTracks() async {
    final raw = await _controller.value.webViewController?.evaluateJavascript(
      source:
          "JSON.stringify((player.getOption('captions','tracklist')||[])"
          ".map(function(t){"
          "return {'code':t.languageCode,'name':t.languageName};}))",
    );
    if (!mounted || raw == null) return;

    // evaluateJavascript hands back either the decoded value or a JSON string
    // depending on platform, so cope with both.
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! List) return;

    final tracks = <CaptionTrack>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final code = entry['code']?.toString() ?? '';
      if (code.isEmpty) continue;
      tracks.add(
        CaptionTrack(
          code: code,
          name: entry['name']?.toString().trim().isNotEmpty == true
              ? entry['name'].toString()
              : code,
        ),
      );
    }
    // Seed the selection from whatever the player is really showing, so the
    // label does not claim a language the viewer is not seeing.
    final activeRaw = await _controller.value.webViewController
        ?.evaluateJavascript(
          source:
              "JSON.stringify((player.getOption('captions','track')||{})"
              ".languageCode||'')",
        );
    if (!mounted) return;
    final active = (activeRaw is String ? jsonDecode(activeRaw) : activeRaw)
        ?.toString();

    setState(() {
      _captionTracks = tracks;
      _captionLanguage ??= tracks.any((t) => t.code == active)
          ? active
          : (tracks.isNotEmpty ? tracks.first.code : null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (orientation == _lastOrientation) return;
    _lastOrientation = orientation;

    _landscapeControlsTimer?.cancel();
    // Show the buttons on arrival in landscape so they are discoverable, then
    // let them time out like any other player control. A rebuild is already
    // scheduled by the dependency change, so no setState here.
    _landscapeControlsVisible = orientation == Orientation.landscape;
    if (_landscapeControlsVisible) _startLandscapeControlsTimer();
  }

  void _startLandscapeControlsTimer() {
    _landscapeControlsTimer?.cancel();
    _landscapeControlsTimer = Timer(widget.landscapeControlsTimeout, () {
      if (mounted) setState(() => _landscapeControlsVisible = false);
    });
  }

  /// Holds the landscape controls open while a menu or sheet is on screen,
  /// so they cannot fade out from under it.
  void _pauseLandscapeAutoHide() => _landscapeControlsTimer?.cancel();

  void _resumeLandscapeAutoHide() {
    // A no-op in portrait, where the controls are not on a timer at all.
    if (_landscapeControlsVisible) _startLandscapeControlsTimer();
  }

  /// Any touch anywhere on the video brings the skip buttons back and restarts
  /// the countdown.
  void _onLandscapeTouch() {
    if (!_landscapeControlsVisible) {
      setState(() => _landscapeControlsVisible = true);
    }
    _startLandscapeControlsTimer();
  }

  @override
  void dispose() {
    _landscapeControlsTimer?.cancel();
    _controller.removeListener(_onPlayerValueChanged);
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // An id we could not parse means the player would sit on a black box
    // forever, so say so instead.
    if (_videoId == null) return _buildInvalidUrlNotice();

    return Stack(
      children: [
        _buildPlayerScaffold(),
        // In landscape YoutubePlayerBuilder discards the page body and renders
        // only the player, taking the ±10s buttons underneath it along with it.
        // Float the same controls over the video instead.
        if (isLandscape) _buildLandscapeSeekOverlay(),
      ],
    );
  }

  Widget _buildInvalidUrlNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingXL,
      ),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: AppSizes.borderRadiusL,
        border: Border.all(color: _kHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_off_rounded,
            color: _kOnSurfaceMuted,
            size: AppSizes.iconL,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Not a valid YouTube link',
            style: _chrome(AppTypography.bodyTextMedium, 14, _kOnSurface),
          ),
          const SizedBox(height: AppSizes.paddingXS),
          Text(
            widget.videoUrl,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _chrome(
              AppTypography.bodyTextXtraSmallMedium,
              10,
              _kOnSurfaceDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerScaffold() {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
        progressColors: ProgressBarColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          bufferedColor: AppColors.primary.withValues(alpha: 0.3),
          backgroundColor: _kSurfaceStrong,
        ),
        onReady: () => widget.onReady?.call(),
        topActions: [
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            // Rebuilt from the controller so the title fills in once the
            // metadata arrives — this list is built by the page, which does
            // not otherwise rebuild when the video loads.
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => Text(
                value.metaData.title,
                style: _chrome(
                  AppTypography.bodyTextSmallSemiBold,
                  12,
                  AppColors.alwaysWhite,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
      builder: (context, player) {
        // No Scaffold and no Expanded here: the widget sizes to its content
        // so a host page can place it anywhere. The host supplies the
        // Scaffold and any SafeArea.
        return FadeTransition(
          opacity: _fadeAnimation,
          // Portrait only — this branch never runs in landscape, where the
          // player must stay full-bleed. `bottom: false` so the widget does
          // not reserve gesture-bar space it does not need.
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlayerCard(player),
                // Sits directly under the player card rather than a full
                // paddingL below it, so the controls read as part of the
                // player instead of a detached row. Left/right stay at
                // paddingL to clear the card's own paddingM margin.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingL,
                    AppSizes.paddingM,
                    AppSizes.paddingL,
                    0,
                  ),
                  child: _buildControlButtons(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Jumps [offset] from the current position, clamped to the video bounds so
  /// a forward skip near the end cannot seek past the duration.
  void _seekBy(Duration offset) {
    final value = _controller.value;
    final duration = value.metaData.duration;
    var target = value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    _controller.seekTo(target);
  }

  /// Applies [code] as the active caption track, or clears captions when it
  /// is null.
  ///
  /// The package only exposes captions through the load-time `enableCaption`
  /// flag, which becomes the iframe's `cc_load_policy` — there is no
  /// controller method for it. The webview handle hanging off the controller's
  /// value is public though, so we drive the YouTube IFrame API's caption
  /// module ourselves.
  ///
  /// `unloadModule('captions')` is a no-op on the current HTML5 player — the
  /// module stays loaded and subtitles keep rendering — so clearing the track
  /// is what actually switches them off. The track object is looked up inside
  /// the page rather than rebuilt here, because YouTube wants its own object,
  /// and it falls back to the first track when [code] is not on offer.
  void _applyCaptionTrack(String? code) {
    final wv = _controller.value.webViewController;
    if (code == null) {
      wv?.evaluateJavascript(
        source: "player.setOption('captions','track',{});",
      );
      return;
    }
    // Language codes come from YouTube (e.g. "hi", "pt-BR"); keep it to
    // characters that cannot break out of the JS string literal.
    final safe = code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    wv?.evaluateJavascript(
      source:
          "player.loadModule('captions');"
          "var tl=player.getOption('captions','tracklist')||[];"
          "var t=tl.filter(function(x){"
          "return x.languageCode==='$safe';})[0]||tl[0];"
          "if(t)player.setOption('captions','track',t);",
    );
  }

  void _toggleCaptions() {
    final enable = !_captionsEnabled;
    _applyCaptionTrack(
      enable ? (_captionLanguage ?? widget.captionLanguage) : null,
    );
    setState(() => _captionsEnabled = enable);
  }

  void _selectCaptionLanguage(CaptionTrack track) {
    _applyCaptionTrack(track.code);
    setState(() {
      _captionLanguage = track.code;
      _captionsEnabled = true;
    });
  }

  /// Name of the track currently selected, for the picker's label.
  String get _captionLanguageLabel {
    for (final track in _captionTracks) {
      if (track.code == _captionLanguage) return track.name;
    }
    return _captionTracks.isNotEmpty ? _captionTracks.first.name : 'Default';
  }

  void _showCaptionLanguagePicker() {
    _pauseLandscapeAutoHide();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.videoPlayerBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(
                  vertical: AppSizes.paddingM - 4,
                ),
                decoration: BoxDecoration(
                  color: _kHairline,
                  borderRadius: AppSizes.borderRadiusCircle,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.paddingL,
                  0,
                  AppSizes.paddingL,
                  AppSizes.paddingS,
                ),
                child: Text(
                  'Subtitle language',
                  style: _chrome(
                    AppTypography.h5SemiBold,
                    20,
                    AppColors.alwaysWhite,
                  ),
                ),
              ),
              // The list can be long on multi-track videos, so let it scroll
              // instead of overflowing in landscape.
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _captionTracks.length,
                  itemBuilder: (context, index) {
                    final track = _captionTracks[index];
                    final selected =
                        track.code == _captionLanguage && _captionsEnabled;
                    return ListTile(
                      title: Text(
                        track.name,
                        style: selected
                            ? _chrome(
                                AppTypography.bodyTextSemiBold,
                                14,
                                AppColors.primary,
                              )
                            : _chrome(
                                AppTypography.bodyTextMedium,
                                14,
                                AppColors.alwaysWhite,
                              ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () {
                        _selectCaptionLanguage(track);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
            ],
          ),
        );
      },
    ).whenComplete(_resumeLandscapeAutoHide);
  }

  /// The same ±10s buttons used under the player in portrait, floated over the
  /// video for landscape. They appear on touch and fade out again after
  /// [CustomYoutubePlayer.landscapeControlsTimeout] so they do not sit over
  /// the video permanently.
  ///
  /// Pinned to the screen edges so they sit clear of the centre play/pause
  /// icon and of the bottom control bar when it appears.
  Widget _buildLandscapeSeekOverlay() {
    return Positioned.fill(
      // The WebView consumes taps before a GestureDetector layered above it
      // ever wins the gesture arena — which is why the player's own controls
      // rarely appear. Raw pointer events still arrive regardless, and
      // `translucent` lets the same touch carry on through to the video.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onLandscapeTouch(),
        child: IgnorePointer(
          // While hidden the buttons must not swallow the tap meant to bring
          // them back.
          ignoring: !_landscapeControlsVisible,
          child: AnimatedOpacity(
            opacity: _landscapeControlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingL,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // The seek zones span 80% of the player height. The Row
                      // below gets the full height from StackFit.expand and
                      // centres them on its cross axis, which is what leaves
                      // the remaining 10% top and bottom clear for the
                      // player's own title bar and progress bar.
                      final seekHeight = constraints.maxHeight * 0.8;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLandscapeSeekButton(
                                icon: Icons.replay_10_rounded,
                                label: '-10s',
                                height: seekHeight,
                                onTap: () => _seekBy(-widget.seekStep),
                              ),
                              _buildLandscapeSeekButton(
                                icon: Icons.forward_10_rounded,
                                label: '+10s',
                                height: seekHeight,
                                onTap: () => _seekBy(widget.seekStep),
                              ),
                            ],
                          ),
                          // Top right keeps the gear clear of the skip
                          // buttons and of the player's own top-left title.
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: AppSizes.paddingM - 4,
                              ),
                              child: _buildSettingsButton(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Landscape skip control: a tall, chrome-less hit target.
  ///
  /// Portrait's chip treatment — surface fill plus hairline border — reads as
  /// an opaque box parked on the video once it is floating over a fullscreen
  /// frame, so landscape drops both and lets the glyph carry the affordance
  /// on its own (with [_kOverVideoShadow] keeping it legible).
  ///
  /// The icon is a size up from portrait's for the same reason: with no chip
  /// behind it, it is the only thing marking the control.
  ///
  /// [height] is 80% of the player height. `HitTestBehavior.opaque` is what
  /// makes that whole column tappable — the default `deferToChild` would only
  /// register hits on the painted glyph, throwing away the large, easy target
  /// that the tall zone exists to provide.
  Widget _buildLandscapeSeekButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppColors.alwaysWhite,
              size: AppSizes.iconL,
              shadows: _kOverVideoShadow,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: _chrome(
                AppTypography.labelSmall,
                10,
                AppColors.alwaysWhite,
              ).copyWith(shadows: _kOverVideoShadow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(Widget player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      decoration: BoxDecoration(
        borderRadius: AppSizes.borderRadiusL,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSizes.borderRadiusL,
        child: player,
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        _buildActionButton(
          icon: Icons.replay_10_rounded,
          label: '-10s',
          onTap: () => _seekBy(-widget.seekStep),
        ),
        const SizedBox(width: AppSizes.paddingM - 4),
        // Play / Pause main button
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) {
              final isPlaying = value.isPlaying;
              return GestureDetector(
                onTap: () {
                  isPlaying ? _controller.pause() : _controller.play();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  // minHeight, not height: a viewer with large OS text
                  // scaling makes the label taller than the box, and a fixed
                  // height would overflow rather than grow.
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isPlaying ? _kSurfaceStrong : AppColors.primary,
                    borderRadius: AppSizes.borderRadiusM,
                    border: Border.all(
                      color: isPlaying ? _kHairline : AppColors.primary,
                    ),
                    boxShadow: isPlaying
                        ? const []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.alwaysWhite,
                        size: AppSizes.iconM,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPlaying ? 'Pause' : 'Play',
                        style: _chrome(
                          AppTypography.buttonMedium,
                          14,
                          AppColors.alwaysWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: AppSizes.paddingM - 4),
        _buildActionButton(
          icon: Icons.forward_10_rounded,
          label: '+10s',
          onTap: () => _seekBy(widget.seekStep),
        ),
        const SizedBox(width: AppSizes.paddingM - 4),
        _buildSettingsButton(),
      ],
    );
  }

  /// Single entry point for the caption controls: one gear that opens a short
  /// icon menu, rather than a row of competing buttons.
  ///
  /// Note there is deliberately no quality picker — `setPlaybackQuality` and
  /// `suggestedQuality` are confirmed no-ops on the IFrame player, so a
  /// picker built from `getAvailableQualityLevels()` would be inert. YouTube
  /// picks quality from bandwidth and player size.
  Widget _buildSettingsButton() {
    final canPickLanguage = _captionTracks.length >= 2;
    return PopupMenuButton<PlayerSetting>(
      tooltip: 'Player settings',
      color: AppColors.videoPlayerBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppSizes.borderRadiusM,
        side: BorderSide(color: _kHairline),
      ),
      position: PopupMenuPosition.under,
      onOpened: _pauseLandscapeAutoHide,
      onCanceled: _resumeLandscapeAutoHide,
      onSelected: (setting) {
        _resumeLandscapeAutoHide();
        switch (setting) {
          case PlayerSetting.subtitles:
            _toggleCaptions();
          case PlayerSetting.subtitleLanguage:
            _showCaptionLanguagePicker();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: PlayerSetting.subtitles,
          child: _buildSettingsMenuRow(
            icon: _captionsEnabled
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_off_rounded,
            label: 'Subtitles',
            trailing: _captionsEnabled ? 'On' : 'Off',
            highlighted: _captionsEnabled,
          ),
        ),
        PopupMenuItem(
          value: PlayerSetting.subtitleLanguage,
          // A video with a single track has nothing to choose between.
          enabled: canPickLanguage,
          child: _buildSettingsMenuRow(
            icon: Icons.translate_rounded,
            label: 'Language',
            trailing: canPickLanguage ? _captionLanguageLabel : 'Only one',
            highlighted: false,
            dimmed: !canPickLanguage,
          ),
        ),
      ],
      child: Container(
        width: AppSizes.iconXXL,
        height: AppSizes.iconXXL,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: AppSizes.borderRadiusM,
          border: Border.all(color: _kHairline),
        ),
        child: Icon(
          Icons.settings_rounded,
          color: _kOnSurface,
          size: AppSizes.iconS,
        ),
      ),
    );
  }

  Widget _buildSettingsMenuRow({
    required IconData icon,
    required String label,
    required String trailing,
    required bool highlighted,
    bool dimmed = false,
  }) {
    final tint = dimmed
        ? _kOnSurfaceDisabled
        : (highlighted ? AppColors.primary : AppColors.alwaysWhite);
    return Row(
      children: [
        Icon(icon, color: tint, size: AppSizes.iconS),
        const SizedBox(width: AppSizes.paddingM - 4),
        Text(
          label,
          style: _chrome(AppTypography.bodyTextSmallSemiBold, 12, tint),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Text(
          trailing,
          style: _chrome(
            AppTypography.bodyTextXtraSmallMedium,
            10,
            dimmed ? _kOnSurfaceDisabled : _kOnSurfaceMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        // See the note on the play/pause button: grow, do not overflow.
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: AppSizes.borderRadiusM,
          border: Border.all(color: _kHairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kOnSurface, size: AppSizes.iconS),
            const SizedBox(height: 2),
            Text(
              label,
              style: _chrome(AppTypography.labelSmall, 10, _kOnSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}
