import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';

/// Pins the broadcast's timeline origin so the on-screen stream timer
/// counts the *session*, not this widget's lifetime.
///
/// The origin comes from the HLS playlist's `EXT-X-PROGRAM-DATE-TIME`,
/// which the player surfaces as `absolutePosition` (the wall-clock instant
/// of the playhead). `absolutePosition - position` is therefore the instant
/// the current seekable window begins — the broadcast start whenever the
/// origin serves DVR from the top of the session.
///
/// Pinned once and never re-derived: the window slides as the session
/// runs, so recomputing it would drag the timer forward, and the player is
/// rebuilt routinely (the live class's video ↔ audio fallback, the
/// webinar's signed-URL refresh) — a per-player origin would reset the
/// clock every time the network wobbled.
///
/// Lives on the page rather than inside [LiveStreamControls] for that same
/// reason.
class LiveStreamClock {
  /// Wall-clock instant the stream's timeline starts at. Null until the
  /// first usable sample.
  DateTime? _origin;

  /// True once [_origin] came from the playlist rather than the device
  /// clock. A playlist origin is shared by every viewer; the local one is
  /// only "since you joined".
  bool _fromPlaylist = false;

  /// Anything older than this is the platform saying "unknown" rather than
  /// a real timestamp: Android returns `C.TIME_UNSET + position` when the
  /// playlist carries no program-date-time, and a bare position (ms since
  /// the epoch) when the timeline is still empty.
  static final DateTime _plausibleFloor = DateTime.utc(2000);

  static bool _usable(DateTime? at) =>
      at != null && at.isAfter(_plausibleFloor);

  /// Feed the player's latest value on every tick. Cheap and idempotent.
  void sample(VideoPlayerValue value) {
    final absolute = value.absolutePosition;
    if (_usable(absolute)) {
      // Upgrade a local origin to the playlist one if it shows up late —
      // the number can jump once, and being right is worth more than
      // being smooth.
      if (!_fromPlaylist) {
        _origin = absolute!.subtract(value.position);
        _fromPlaylist = true;
      }
      return;
    }
    _origin ??= DateTime.now();
  }

  /// How long the stream has been running at the current playhead, or null
  /// while the origin is still unknown. Reads at the *playhead*, so
  /// scrubbing back into the DVR window rewinds the timer with it.
  Duration? elapsedAt(VideoPlayerValue value) {
    final origin = _origin;
    if (origin == null) return null;
    final absolute = value.absolutePosition;
    final elapsed = _fromPlaylist && _usable(absolute)
        ? absolute!.difference(origin)
        : DateTime.now().difference(origin);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Drops the pin. Call when the session ends, not when the player is
  /// rebuilt.
  void reset() {
    _origin = null;
    _fromPlaylist = false;
  }
}

/// The live player's controls, in the layout every streaming site uses:
/// a full-width scrubber, and directly beneath it a single row of
/// play/pause, mute, the LIVE badge with the running stream timer, and
/// fullscreen.
///
/// Replaces `better_player_plus`'s own controls rather than sitting on top
/// of them — hand it to
/// [BetterPlayerControlsConfiguration.customControlsBuilder] alongside
/// [BetterPlayerTheme.custom]. Three reasons it has to own the whole bar:
///
///  * the package draws **no** progress row at all for a `liveStream`
///    source — its bottom bar swaps the row for the word "LIVE" and stops;
///  * an overlay drawn above the package's bar collided with the icons it
///    centres in that bar, and duplicated the LIVE label;
///  * controls belong to the player, so they travel with it wherever it
///    is mounted. An overlay in the page's own stack does not.
///
/// Shown when the session starts and after every touch, then faded back
/// out once the viewer has left it alone for [_autoHideAfter] — except
/// while the stream is paused or the scrubber is being dragged, when
/// hiding the bar would take away the thing being used.
class LiveStreamControls extends StatefulWidget {
  final BetterPlayerController controller;

  /// Page-owned so the stream timer survives the player being rebuilt.
  final LiveStreamClock clock;

  /// The package's own visibility sink. Fed once — these controls do not
  /// hide — so the rest of the player agrees with what is on screen.
  final void Function(bool visible) onControlsVisibilityChanged;

  /// Lift for a system inset the page does not already absorb. Needed
  /// wherever the stage runs to the physical bottom of the screen, where
  /// the navigation bar would otherwise sit on the bar.
  final double bottomInset;

  /// What the expand button does, when the page would rather handle it
  /// than let the package push its own fullscreen route.
  ///
  /// That route goes onto the **root** navigator, so it lands outside the
  /// page's `BlocProvider` — the chat panel and the raise-hand control
  /// cannot be rendered inside it without re-providing the cubit and
  /// duplicating the page's whole landscape layout. Rotating into the
  /// page's own landscape gives the same full-stage video *and* keeps
  /// those controls, which a class needs far more than it needs a route.
  ///
  /// Null falls back to the package's fullscreen.
  final VoidCallback? onToggleExpand;

  /// Whether the stage is currently expanded, for the button's icon.
  /// Ignored unless [onToggleExpand] is set.
  final bool isExpanded;

  /// Height of the bar along the bottom of the stage. Pages floating
  /// anything else over the video use it to keep clear.
  static const double barHeight =
      _LiveStreamControlsState._scrubRowHeight +
      _LiveStreamControlsState._buttonRowHeight;

  const LiveStreamControls({
    super.key,
    required this.controller,
    required this.clock,
    required this.onControlsVisibilityChanged,
    this.bottomInset = 0,
    this.onToggleExpand,
    this.isExpanded = false,
  });

  @override
  State<LiveStreamControls> createState() => _LiveStreamControlsState();
}

class _LiveStreamControlsState
    extends BetterPlayerControlsState<LiveStreamControls>
    with SingleTickerProviderStateMixin {
  /// How close to the window's end still counts as live, as a share of the
  /// window, bounded below and above.
  ///
  /// Proportional rather than fixed: a low-latency playhead drifts by a
  /// segment or two on its own, so a tight bound makes the badge flicker
  /// between LIVE and GO LIVE — but a flat 10s on a 12s window would mean
  /// the badge never left LIVE however far back the student scrubbed.
  static const _liveEdgeSlackShare = 0.25;
  static const _minLiveEdgeSlack = Duration(seconds: 3);
  static const _maxLiveEdgeSlack = Duration(seconds: 10);

  /// Below this there is nothing worth scrubbing and the track is drawn
  /// full and inert instead. Low on purpose: a low-latency origin holds
  /// only a handful of 2s segments, and 10s of rewind is still 10s.
  static const _minSeekableWindow = Duration(seconds: 5);

  /// Live edges reject a seek to the exact end (nothing is buffered past
  /// it), so "go live" aims just short of it.
  static const _liveEdgeMargin = Duration(seconds: 1);

  /// Idle time before the bar fades out. Long enough to read the stream
  /// timer off it without having to touch the screen twice.
  static const _autoHideAfter = Duration(milliseconds: 3500);

  static const _trackHeight = 4.0;

  /// Tall enough for the thumb and its press halo to paint inside the row
  /// rather than over the buttons below it.
  static const _scrubRowHeight = 28.0;
  static const _buttonRowHeight = 42.0;

  /// The one margin everything on this bar squares up to: the scrubber's
  /// track ends here, and so do the outermost button glyphs — the play
  /// icon on the left, fullscreen and the overflow button on the right.
  ///
  /// Derived rather than chosen. `BaseSliderTrackShape` insets the track
  /// by `max(overlay, thumb) / 2` so the thumb has somewhere to sit at
  /// either end, which for this theme is [_overlayRadius]. Taking that as
  /// the margin means the scrubber needs no padding of its own — anything
  /// added there would show up as the track and the buttons disagreeing
  /// about where the edge is. The buttons are padded to match instead,
  /// less the gap [_ControlIcon] leaves centring a [_iconSize] glyph
  /// inside a [_iconBox]-wide tap target.
  static const _overlayRadius = 14.0;
  static const _thumbRadius = 7.0;
  static const _edgeInset = _overlayRadius;
  static const _iconBox = 40.0;
  static const _iconSize = 22.0;
  static const _iconGlyphInset = (_iconBox - _iconSize) / 2;

  /// Fade behind the top-right overflow button.
  static const _topScrimHeight = 56.0;

  Timer? _ticker;
  Timer? _hideTimer;
  late final AnimationController _pulse;

  VideoPlayerValue? _value;

  /// Where the thumb is being dragged to, in milliseconds. Non-null only
  /// mid-drag, when it takes over from the real playhead so the thumb
  /// doesn't fight the 500ms position updates.
  double? _scrubMs;

  /// Volume to come back to when un-muting.
  double _volumeBeforeMute = 1.0;

  /// Furthest point the timeline has reached, in milliseconds.
  ///
  /// The scrubber cannot just use `value.duration`: the Android side sends
  /// `duration` **once**, inside `sendInitialized`, so on a live source it
  /// is frozen at whatever the window held at startup — and on an origin
  /// whose DVR grows with the broadcast it is stale seconds later.
  /// Tracking the high-water mark of `max(duration, position)` instead
  /// keeps the track's right-hand end at the live edge, and keeps it from
  /// shrinking under the thumb when the student scrubs back.
  double _windowHighWaterMs = 0;

  @override
  BetterPlayerController? get betterPlayerController => widget.controller;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      widget.controller.betterPlayerControlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _value;

  /// The base class calls this whenever one of its own helpers acts on
  /// the player; it means the same thing here as a touch does.
  @override
  void cancelAndRestartTimer() => _keepAlive();

  /// Bring the bar back if it has gone, or push its disappearance back if
  /// it is already up. Every control on the bar routes through here, so
  /// using one never starts a countdown the viewer can't see.
  void _keepAlive() {
    if (controlsNotVisible) {
      _setControlsVisible(true);
    } else {
      _restartHideTimer();
    }
  }

  void _setControlsVisible(bool visible) {
    if (!mounted || controlsNotVisible == !visible) return;
    // The base class owns the flag and posts the package's own hide event
    // off it, so the rest of the player stays in step.
    changePlayerControlsNotVisible(!visible);
    widget.onControlsVisibilityChanged(visible);
    if (visible) {
      _restartHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_autoHideAfter, () {
      if (!mounted) return;
      // Two cases where hiding would take away what is in use: a drag in
      // progress, and a paused stage — a bar that vanishes over a stopped
      // video leaves nothing to press to start it again. Wait it out
      // rather than dropping the countdown, so the bar still goes once
      // the viewer is done.
      if (_scrubMs != null || widget.controller.isPlaying() != true) {
        _restartHideTimer();
        return;
      }
      _setControlsVisible(false);
    });
  }

  @override
  void initState() {
    super.initState();
    controlsNotVisible = !widget
        .controller
        .betterPlayerControlsConfiguration
        .showControlsOnInitialize;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Polled rather than bound to `videoPlayerController`: the page swaps
    // that controller out under us on every fallback and re-resolve, and a
    // 500ms read of a value the player already refreshes on that cadence
    // costs nothing.
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _read());
    _read();
    if (!controlsNotVisible) _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onControlsVisibilityChanged(!controlsNotVisible);
    });
  }

  @override
  void didUpdateWidget(covariant LiveStreamControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _scrubMs = null;
      // A rebuilt player starts on a fresh timeline; carrying the old
      // high-water mark over would stretch the track past the new one.
      _windowHighWaterMs = 0;
      _read();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _read() {
    if (!mounted) return;
    // The whole player can be torn down between ticks; a disposed
    // controller throws rather than returning null.
    VideoPlayerValue? value;
    try {
      value = widget.controller.videoPlayerController?.value;
    } catch (_) {
      value = null;
    }
    if (value == null || !value.initialized) {
      if (_value != null) setState(() => _value = null);
      return;
    }
    final current = value;
    widget.clock.sample(current);
    _trackWindow(current);
    final synced = _syncLiveDuration(current);
    setState(() => _value = synced);
  }

  /// Keeps the player's own `duration` in step with the live edge this
  /// widget has actually observed, and returns whatever the value is
  /// afterwards.
  ///
  /// `VideoPlayerController.seekTo` clamps its target to `value.duration`
  /// (`if (position > value.duration) positionToSeek = value.duration`),
  /// and on a live source that number is whatever the window happened to
  /// hold at startup: the Android side sends `duration` exactly once,
  /// from `sendInitialized`, and never again. Once the timeline runs past
  /// it, every forward seek is silently pulled back to it.
  ///
  /// That is what stopped GO LIVE working, and it explains why dragging
  /// still did: scrubbing *back* targets a small position that lands
  /// inside the stale bound and is left alone, while jumping *forward* to
  /// the live edge targets a large one and gets yanked back to a stale
  /// 12-ish seconds.
  ///
  /// Writing the observed edge back is the least invasive fix available
  /// from outside the package: `value` is a plain [ValueNotifier] field,
  /// and `duration` is read only for that clamp, the `initialized` flag,
  /// and the finished check — all three want the live edge anyway. It
  /// only ever moves forward, so it cannot pull the track's end backwards
  /// under the thumb.
  VideoPlayerValue _syncLiveDuration(VideoPlayerValue value) {
    final player = widget.controller.videoPlayerController;
    if (player == null) return value;
    // Belt and braces: rewriting duration is only ever right for a live
    // source, where the platform's single reading goes stale by design.
    bool live;
    try {
      live = widget.controller.isLiveStream();
    } catch (_) {
      return value;
    }
    if (!live) return value;

    final edge = Duration(milliseconds: _windowHighWaterMs.round());
    final known = value.duration;
    if (known != null && !known.isNegative && known >= edge) return value;
    player.value = player.value.copyWith(duration: edge);
    return player.value;
  }

  /// Folds the latest sample into [_windowHighWaterMs]. Implausible
  /// durations are dropped rather than clamped: Android reports an unset
  /// live duration as a negative sentinel, which would otherwise pin the
  /// track's end behind its start.
  void _trackWindow(VideoPlayerValue value) {
    void offer(Duration? d) {
      if (d == null || d.isNegative || d > const Duration(hours: 24)) return;
      final ms = d.inMilliseconds.toDouble();
      if (ms > _windowHighWaterMs) _windowHighWaterMs = ms;
    }

    offer(value.duration);
    offer(value.position);
  }

  /// The seekable window, or null when there isn't one worth showing.
  Duration? get _window {
    if (_value == null) return null;
    final window = Duration(milliseconds: _windowHighWaterMs.round());
    return window < _minSeekableWindow ? null : window;
  }

  Duration get _position {
    final position = _value?.position ?? Duration.zero;
    return position.isNegative ? Duration.zero : position;
  }

  bool get _atLiveEdge {
    final window = _window;
    if (window == null) return true;
    var slack = window * _liveEdgeSlackShare;
    if (slack < _minLiveEdgeSlack) slack = _minLiveEdgeSlack;
    if (slack > _maxLiveEdgeSlack) slack = _maxLiveEdgeSlack;
    return window - _position <= slack;
  }

  bool get _muted => (_value?.volume ?? 1.0) <= 0;

  bool get _expanded => widget.onToggleExpand != null
      ? widget.isExpanded
      : widget.controller.isFullScreen;

  Future<void> _seekTo(Duration target) async {
    try {
      await widget.controller.seekTo(target);
    } catch (_) {
      // A seek onto a segment the origin has already rolled off throws
      // rather than returning; the next tick redraws from wherever the
      // player settled.
    }
  }

  Future<void> _goLive() async {
    _keepAlive();
    // Take a fresh sample first. The edge has moved on since the last
    // tick, and it is also what [_syncLiveDuration] keys off — seeking
    // before that has caught up is seeking against a stale ceiling.
    _read();
    final window = _window;
    if (window == null) return;
    await _seekTo(window - _liveEdgeMargin);
    await widget.controller.play();
  }

  void _togglePlay() {
    _keepAlive();
    if (widget.controller.isPlaying() == true) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _toggleMute() {
    _keepAlive();
    if (_muted) {
      widget.controller.setVolume(
        _volumeBeforeMute <= 0 ? 1.0 : _volumeBeforeMute,
      );
    } else {
      _volumeBeforeMute = _value?.volume ?? 1.0;
      widget.controller.setVolume(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_value == null) return const SizedBox.shrink();

    // The package's own fullscreen route always runs to the physical
    // bottom edge, whatever the hosting page's layout does. When the page
    // owns expansion instead, it works its own inset out.
    final inset =
        widget.onToggleExpand == null && widget.controller.isFullScreen
        ? MediaQuery.viewPaddingOf(context).bottom
        : widget.bottomInset;

    return buildLTRDirectionality(
      Stack(
        fit: StackFit.expand,
        children: [
          // First child, so it is hit-tested *last*: a touch that lands on
          // a control belongs to that control, and only a touch on bare
          // video reaches here to toggle the bar.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setControlsVisible(controlsNotVisible),
              child: const SizedBox.expand(),
            ),
          ),
          // Outside the fade: buffering is worth showing whether or not
          // the viewer has the bar up.
          if (isLoading(_value))
            Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.alwaysWhite,
                ),
              ),
            ),
          IgnorePointer(
            ignoring: controlsNotVisible,
            child: AnimatedOpacity(
              opacity: controlsNotVisible ? 0 : 1,
              duration: betterPlayerControlsConfiguration.controlsHideTime,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (betterPlayerControlsConfiguration.enableOverflowMenu) ...[
                    // Its own scrim: the corner of a lit classroom is often the
                    // brightest part of the frame, and a bare white glyph on it
                    // disappears.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: _topScrimHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.videoPlayerBgColor.withValues(
                                  alpha: 0.45,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      // Squares the glyph up with the right-hand end of the track
                      // and the fullscreen icon below it.
                      right: _edgeInset - _iconGlyphInset,
                      child: _ControlIcon(
                        icon:
                            betterPlayerControlsConfiguration.overflowMenuIcon,
                        tooltip: 'More',
                        height: _iconBox,
                        onTap: () {
                          _keepAlive();
                          onShowMoreClicked();
                        },
                      ),
                    ),
                  ],
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildControlCluster(inset),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCluster(double inset) {
    final window = _window;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.videoPlayerBgColor.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrubber first, button row under it — the order every
            // streaming player uses, so the track reads as the edge of
            // the video rather than as one more control in the row.
            SizedBox(
              height: _scrubRowHeight,
              child: window == null
                  ? const _InertLiveTrack()
                  : _buildScrubber(window),
            ),
            SizedBox(
              height: _buttonRowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _edgeInset - _iconGlyphInset,
                ),
                child: Row(
                  children: [
                    _ControlIcon(
                      icon: widget.controller.isPlaying() == true
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      tooltip: widget.controller.isPlaying() == true
                          ? 'Pause'
                          : 'Play',
                      onTap: _togglePlay,
                    ),
                    _ControlIcon(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      tooltip: _muted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 4),
                    // Where a VOD player puts its elapsed / total
                    // timestamp.
                    _LiveBadge(
                      atLiveEdge: _atLiveEdge,
                      pulse: _pulse,
                      onGoLive: window == null ? null : _goLive,
                    ),
                    const SizedBox(width: 8),
                    // Takes every spare pixel so the expand button is
                    // pinned to the row's end.
                    //
                    // This was a `Flexible` timer followed by a `Spacer`,
                    // which left a gap to the *right* of the expand
                    // button: a loose `Flexible` hands its unused width
                    // back to the Row as leftover, and the default
                    // `MainAxisAlignment.start` parks leftover after the
                    // last child. Tight (`Expanded`) gives nothing back.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StreamTimerLabel(
                          elapsed: widget.clock.elapsedAt(_value!),
                        ),
                      ),
                    ),
                    // Last in the row, so its glyph is what squares up
                    // with the right-hand end of the track above it.
                    if (betterPlayerControlsConfiguration.enableFullscreen)
                      _ControlIcon(
                        icon: _expanded
                            ? betterPlayerControlsConfiguration
                                  .fullscreenDisableIcon
                            : betterPlayerControlsConfiguration
                                  .fullscreenEnableIcon,
                        tooltip: _expanded ? 'Exit fullscreen' : 'Fullscreen',
                        onTap: () {
                          _keepAlive();
                          (widget.onToggleExpand ??
                              widget.controller.toggleFullScreen)();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubber(Duration window) {
    final maxMs = window.inMilliseconds.toDouble();
    final playedMs = _scrubMs ?? _position.inMilliseconds.toDouble();
    final buffered = _value!.buffered;
    final bufferedMs = buffered.isEmpty
        ? playedMs
        : buffered.last.end.inMilliseconds.toDouble();

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: _trackHeight,
        activeTrackColor: AppColors.primary,
        // Read against bright video as well as dark: the played half is
        // brand-coloured, so the rest has to be light enough to see the
        // line at all, not merely darker than the played half.
        inactiveTrackColor: AppColors.alwaysWhite.withValues(alpha: 0.45),
        secondaryActiveTrackColor: AppColors.alwaysWhite.withValues(alpha: 0.7),
        // White, not brand: at the live edge the thumb sits on top of a
        // full brand-coloured track and would otherwise vanish into it.
        thumbColor: AppColors.alwaysWhite,
        overlayColor: AppColors.alwaysWhite.withValues(alpha: 0.24),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: _thumbRadius,
          pressedElevation: 0,
          elevation: 2,
        ),
        overlayShape: const RoundSliderOverlayShape(
          overlayRadius: _overlayRadius,
        ),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        min: 0,
        max: maxMs,
        value: playedMs.clamp(0, maxMs),
        secondaryTrackValue: bufferedMs.clamp(0, maxMs),
        onChanged: (v) {
          _keepAlive();
          setState(() => _scrubMs = v);
        },
        onChangeEnd: (v) {
          setState(() => _scrubMs = null);
          _keepAlive();
          _seekTo(Duration(milliseconds: v.round()));
        },
      ),
    );
  }
}

/// What the scrubber becomes when the origin publishes too short a window
/// to seek in: a full track, drawn but inert. A live stream with nothing
/// behind it *is* at 100%, and a bar that disappears reads as a broken bar
/// rather than an absent one.
class _InertLiveTrack extends StatelessWidget {
  const _InertLiveTrack();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: _LiveStreamControlsState._trackHeight,
        // Matches where the real track starts and stops, so swapping
        // between them doesn't shift the line.
        margin: const EdgeInsets.symmetric(
          horizontal: _LiveStreamControlsState._edgeInset,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(
            _LiveStreamControlsState._trackHeight,
          ),
        ),
      ),
    );
  }
}

/// One control-row button, sized to a comfortable tap target.
class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Defaults to filling its parent, which is what the bottom row wants.
  /// The top-right corner has no bounded height to fill, so it passes one.
  final double height;

  const _ControlIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.height = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _LiveStreamControlsState._iconBox,
          height: height,
          child: Icon(
            icon,
            size: _LiveStreamControlsState._iconSize,
            color: AppColors.alwaysWhite,
          ),
        ),
      ),
    );
  }
}

/// LIVE while the playhead is at the edge; a tappable GO LIVE once the
/// viewer has scrubbed back into the DVR window. One control rather than
/// two so the row stays readable at phone width.
class _LiveBadge extends StatelessWidget {
  final bool atLiveEdge;
  final Animation<double> pulse;
  final Future<void> Function()? onGoLive;

  const _LiveBadge({
    required this.atLiveEdge,
    required this.pulse,
    required this.onGoLive,
  });

  @override
  Widget build(BuildContext context) {
    final live = atLiveEdge;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live
            ? AppColors.error
            : AppColors.alwaysWhite.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(pulse),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.alwaysWhite,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Icon(
              Icons.skip_next_rounded,
              size: 12,
              color: AppColors.alwaysWhite,
            ),
          const SizedBox(width: 5),
          Text(
            live ? 'LIVE' : 'GO LIVE',
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (live || onGoLive == null) return badge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onGoLive,
      child: badge,
    );
  }
}

/// `H:MM:SS` once the session passes the hour, `MM:SS` before that.
/// Tabular figures so the row doesn't shuffle sideways every second.
class _StreamTimerLabel extends StatelessWidget {
  final Duration? elapsed;

  const _StreamTimerLabel({required this.elapsed});

  static String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = elapsed;
    return Text(
      value == null ? '--:--' : _format(value),
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.alwaysWhite,
        // labelSmall's own 10 is a caption size; on a control bar over
        // video, beside a 9px LIVE chip, the running time is the thing
        // people actually read off the bar.
        fontSize: Screen.getFontSizeCapped(12),
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
