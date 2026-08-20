import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/moving_watermark.dart';
import 'package:nexora/features/courses/presentation/widgets/custom_youtube_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pod_player/pod_player.dart';

import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';

/// Displays a course lecture. Two renderers sit behind one route, picked
/// once from the URL and never swapped afterwards:
///
///   * **YouTube** watch / youtu.be / shorts / embed / live URL →
///     [CustomYoutubePlayer], which embeds YouTube's own **IFrame player**
///     and layers custom ±10s skip / caption controls on top of it.
///   * **Everything else** (network MP4 / HLS, Google Drive share links) →
///     [PodVideoPlayer] over a [PodPlayerController].
///
/// The YouTube branch used to run through `pod_player` as well, via
/// `PlayVideoFrom.youtube` / `PodPlayerController.getYoutubeUrls`. Both
/// resolve YouTube's raw progressive stream URLs with `youtube_explode_dart`
/// and hand them to `video_player`, so the video played entirely outside
/// YouTube's player — no ads, no branding, no watch-page attribution. That
/// breaches the YouTube API Services Terms, so it is gone; YouTube lectures
/// now render in YouTube's player.
///
/// Consequences of that swap, all deliberate:
///
///   * **No quality picker on YouTube lectures.** `setPlaybackQuality` and
///     `suggestedQuality` are confirmed no-ops on the IFrame player — YouTube
///     picks quality from bandwidth and player size. The old picker only ever
///     appeared for YouTube (it was fed by `getYoutubeUrls`), so it is
///     removed rather than left as an inert control.
///   * **No watermark on YouTube lectures.** [MovingWatermark] would sit over
///     YouTube's surface, including pre-roll ads and the *Skip Ad* button,
///     which Developer Policy III.I.5 prohibits. Non-YouTube lectures keep it.
///   * **Device orientation is unlocked** while a YouTube lecture is open, so
///     rotating the handset triggers the player's landscape fullscreen. The
///     app is otherwise portrait-locked in `main.dart`; [dispose] puts it back.
///
/// When [coursePurchasedId] and [nodeId] are both supplied (i.e. the user
/// owns this course), the page tracks playback position on either renderer
/// and fires a completion POST through [ContentCompletionService] the first
/// time the watched ratio crosses 75%. Subsequent seeks/replays are no-ops
/// thanks to a local + service-level dedup.
class VideoPlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final int coursePurchasedId;
  final String nodeId;
  final bool activateWatermark;

  const VideoPlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.coursePurchasedId = 0,
    this.nodeId = '',
    this.activateWatermark = false,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  PodPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _completionFired = false;

  /// True only once `initialise()` has returned successfully.
  ///
  /// `pod_player`'s [PodPlayerController.addListener] and
  /// [PodPlayerController.removeListener] both funnel through an
  /// un-awaited `_checkAndWaitTillInitialized().then(...)` with no error
  /// handler. When initialisation failed, that helper re-throws the
  /// stored error — so touching listeners on a dead controller escapes
  /// as an unhandled async error even though [_initPlayer] already
  /// caught the failure and showed the error state. Gate every listener
  /// call on this flag.
  bool _playerReady = false;
  bool get _trackingEnabled =>
      widget.coursePurchasedId > 0 && widget.nodeId.isNotEmpty;

  final GlobalKey _playerKey = GlobalKey();
  OverlayEntry? _watermarkEntry;
  bool _isFullScreen = false;
  String _userName = '';
  String _phoneNumber = '';
  double _lastAspectRatio = 16 / 9;

  /// Which renderer this page is running. Decided once in [initState] — the
  /// URL never changes for the lifetime of the route.
  late final bool _isYoutube;

  /// Bare 11-character video id, or the original string when we could not
  /// extract one (the player then shows its "not a valid YouTube link" card
  /// with the offending value). YouTube branch only.
  String? _youtubeId;

  /// Last YouTube IFrame error code reported by the player, or null while
  /// playback is healthy. Every code we can get here is permanent.
  int? _youtubeErrorCode;

  /// Forces a fresh [CustomYoutubePlayer] (and therefore a fresh controller)
  /// when the user retries after an *unrecognised* error. Never bumped for a
  /// known-permanent code — remounting a WebView is expensive and retrying
  /// an embedding-disabled video cannot succeed.
  int _youtubeAttempt = 0;

  // TEMP — hardcoded URL for end-to-end testing the YouTube path
  // without waiting for the backend to ship a `Youtube` content node.
  // Set to `null` to fall through to `widget.url`. Remove this
  // override before the next production build.
  //
  // The nullable type is the whole point — flipping the value to
  // `null` disables the override — so silence the analyzer hint that
  // would otherwise want it narrowed to non-null.
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? _kDebugYoutubeOverride = null;

  /// Resolves to [_kDebugYoutubeOverride] when set, otherwise the URL
  /// the route handed us.
  String get _effectiveUrl => _kDebugYoutubeOverride ?? widget.url;

  @override
  void initState() {
    super.initState();
    debugPrint('Video URL: $_effectiveUrl');
    // Honour the service's session cache — if the same node already
    // completed during this app run, skip the listener altogether.
    if (_trackingEnabled &&
        sl<ContentCompletionService>().isMarked(
          widget.coursePurchasedId,
          widget.nodeId,
        )) {
      _completionFired = true;
    }

    _isYoutube = _isYoutubeUrl(_effectiveUrl);
    if (_isYoutube) {
      _initYoutube();
    } else {
      _initPlayer();
    }
  }

  // ───────────────────────── YouTube branch ─────────────────────────

  void _initYoutube() {
    _youtubeId = _youtubeVideoId(_effectiveUrl);
    _isLoading = false;

    // The app is portrait-locked globally in `main.dart`. Lift that for as
    // long as this page is up so a physical rotation reaches the player's
    // landscape fullscreen — the package's own fullscreen button drives
    // orientation itself and works either way, but rotation would not.
    // `dispose` restores the portrait lock.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Fired on every player tick. Mirrors [_onPlaybackTick] for the YouTube
  /// renderer: position vs. duration, completion POST the first time the
  /// ratio clears 75%.
  void _onYoutubeProgress(Duration position, Duration duration) {
    if (_completionFired) return;
    final total = duration.inMilliseconds;
    if (total <= 0) return;
    if (position.inMilliseconds / total < 0.75) return;
    _completionFired = true;
    sl<ContentCompletionService>().markCompleted(
      coursePurchasedId: widget.coursePurchasedId,
      jsonContentId: widget.nodeId,
    );
  }

  void _onYoutubeError(int code) {
    if (!mounted) return;
    setState(() => _youtubeErrorCode = code);
  }

  /// Human-readable text for a YouTube IFrame API error code.
  static String _youtubeErrorMessage(int code) {
    switch (code) {
      case 1:
      case 2:
        return 'This lecture has an invalid video link.';
      case 5:
        return 'This video cannot be played on this device.';
      case 100:
        return 'This video is unavailable — it may have been removed or\n'
            'made private.';
      case 101:
      case 150:
        // By far the most common one in production: many uploaders disable
        // embedding, and no retry will ever change that.
        return 'The owner of this video has disabled playback outside\n'
            'YouTube.';
      default:
        return 'Failed to load video';
    }
  }

  /// Whether retrying could plausibly help. Every documented code is
  /// permanent, so only an unrecognised one gets a Retry button.
  static bool _youtubeErrorIsPermanent(int code) =>
      const {1, 2, 5, 100, 101, 150}.contains(code);

  static final RegExp _youtubeIdPattern = RegExp(r'^[_\-a-zA-Z0-9]{11}$');

  /// Video-id segment names used by the URL shapes an admin might paste.
  static const Set<String> _youtubeIdSegments = {
    'shorts',
    'embed',
    'live',
    'v',
    'e',
  };

  /// Extracts the bare 11-character id from any YouTube URL shape.
  ///
  /// [YoutubePlayer.convertUrlToId] is stricter than the links a CMS
  /// actually emits: its regexes require `https` (so an `http://` link
  /// silently fails), and they cover neither `/live/<id>` nor
  /// `youtube-nocookie.com/watch?v=`. Parsing the URI ourselves and handing
  /// the player a bare id — which it accepts verbatim — sidesteps all of
  /// that. Returns null when no id is present, e.g. a channel link.
  static String? _youtubeVideoId(String url) {
    final trimmed = url.trim();
    if (_youtubeIdPattern.hasMatch(trimmed) && !trimmed.contains('http')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    String? candidate;
    if (uri.host.toLowerCase().endsWith('youtu.be')) {
      candidate = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else {
      candidate = uri.queryParameters['v'];
      if (candidate == null || candidate.isEmpty) {
        final segments = uri.pathSegments;
        for (var i = 0; i < segments.length - 1; i++) {
          if (_youtubeIdSegments.contains(segments[i])) {
            candidate = segments[i + 1];
            break;
          }
        }
      }
    }

    if (candidate == null) return null;
    return _youtubeIdPattern.hasMatch(candidate) ? candidate : null;
  }

  // ───────────────────────── pod_player branch ──────────────────────

  Future<void> _initPlayer() async {
    final url = _effectiveUrl;

    final playFrom = _isGoogleDriveUrl(url)
        ? PlayVideoFrom.network(_getGoogleDriveDirectUrl(url))
        : PlayVideoFrom.network(url);

    final controller = PodPlayerController(
      podPlayerConfig: const PodPlayerConfig(autoPlay: true),
      playVideoFrom: playFrom,
    );
    _controller = controller;

    try {
      await controller.initialise();
      _playerReady = true;
      if (_trackingEnabled) {
        _controller?.addListener(_onPlaybackTick);
      }
      _controller?.addListener(_onControllerUpdate);

      if (widget.activateWatermark) {
        final profileState = sl<ProfileCubit>().state;
        profileState.maybeWhen(
          loaded: (profile) {
            _userName = profile.name ?? '';
            _phoneNumber = profile.phoneNumber ?? '';
          },
          updated: (profile) {
            _userName = profile.name ?? '';
            _phoneNumber = profile.phoneNumber ?? '';
          },
          updating: (profile) {
            _userName = profile.name ?? '';
            _phoneNumber = profile.phoneNumber ?? '';
          },
          orElse: () {},
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWatermarkOverlay();
        });
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load video';
          _isLoading = false;
        });
      }
    }
  }

  /// `youtu.be`, `youtube.com`, `m.youtube.com`, `music.youtube.com`,
  /// and `youtube-nocookie.com` all route to the embedded YouTube player.
  /// Anything else is treated as a direct media URL.
  static bool _isYoutubeUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.endsWith('youtube.com') ||
        host.endsWith('youtu.be') ||
        host.endsWith('youtube-nocookie.com');
  }

  /// `drive.google.com` and `drive.usercontent.google.com` both carry
  /// Drive-hosted files. Docs/Slides/Sheets links are a different host
  /// (`docs.google.com`) and are never video, so they aren't matched.
  static bool _isGoogleDriveUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'drive.google.com' ||
        host == 'drive.usercontent.google.com';
  }

  /// Extracts the Drive file id from any of the link shapes an admin is
  /// likely to paste, or `null` when the URL carries no id (e.g. a
  /// folder link, which has no single file to play).
  ///
  ///   `/file/d/<ID>/view`   `/file/d/<ID>/preview`
  ///   `/uc?id=<ID>`         `/open?id=<ID>`
  ///   `/download?id=<ID>`   (drive.usercontent host)
  static String? _driveFileId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Path form: /file/d/<ID>/... — the id is the segment after "d".
    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    if (dIndex != -1 && dIndex + 1 < segments.length) {
      final id = segments[dIndex + 1];
      if (id.isNotEmpty) return id;
    }

    // Query form: ?id=<ID>. Read the parsed query rather than regexing
    // the raw string — the old `id=([^&]+)` pattern also matched the
    // tail of unrelated params (e.g. `resourcekey`, `userid`).
    final queryId = uri.queryParameters['id'];
    if (queryId != null && queryId.isNotEmpty) return queryId;

    return null;
  }

  /// Rewrites a Drive share link into a URL that serves media bytes.
  ///
  /// Uses `drive.usercontent.google.com/download` with `confirm=t`: the
  /// old `drive.google.com/uc?export=download` endpoint answers with an
  /// HTML virus-scan interstitial for files above roughly 100 MB — i.e.
  /// most lecture recordings — which the player can't decode, so the
  /// lecture failed to open and the 75% completion never fired. The
  /// `confirm=t` parameter skips that interstitial.
  ///
  /// Returns the input unchanged when no file id can be extracted, so a
  /// folder or already-direct link still gets a play attempt.
  static String _getGoogleDriveDirectUrl(String url) {
    final id = _driveFileId(url);
    if (id == null) return url;
    return 'https://drive.usercontent.google.com/download'
        '?id=$id&export=download&confirm=t';
  }

  void _onControllerUpdate() {
    final newRatio = _controller?.videoPlayerValue?.aspectRatio;
    if (newRatio != null && newRatio > 0 && newRatio != _lastAspectRatio) {
      if (mounted) {
        setState(() {
          _lastAspectRatio = newRatio;
        });
      }
    }
  }

  /// Listener fired on every frame the underlying video controller
  /// publishes. Compares position vs. duration and triggers the
  /// completion POST the first time the ratio clears 75%. Detaches
  /// itself once fired so the remaining playback runs zero work.
  void _onPlaybackTick() {
    if (_completionFired) return;
    final controller = _controller;
    if (controller == null) return;
    final dur = controller.totalVideoLength.inMilliseconds;
    if (dur <= 0) return;
    final pos = controller.currentVideoPosition.inMilliseconds;
    if (pos / dur < 0.75) return;
    _completionFired = true;
    controller.removeListener(_onPlaybackTick);
    sl<ContentCompletionService>().markCompleted(
      coursePurchasedId: widget.coursePurchasedId,
      jsonContentId: widget.nodeId,
    );
  }

  @override
  void dispose() {
    _watermarkEntry?.remove();
    _watermarkEntry = null;

    final controller = _controller;
    if (controller != null) {
      // Listeners are only safe to detach if they were ever attached —
      // see [_playerReady]. `dispose()` itself is synchronous and does not
      // go through the initialisation gate, so it is always safe to call.
      if (_playerReady) {
        if (_trackingEnabled) controller.removeListener(_onPlaybackTick);
        controller.removeListener(_onControllerUpdate);
      }
      controller.dispose();
    }
    // Reset System UI overlays + orientation when leaving. Both players
    // change them: pod_player's fullscreen toggle, and the YouTube branch's
    // orientation unlock plus YoutubePlayerBuilder's immersive-sticky mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _showWatermarkOverlay() {
    if (_watermarkEntry != null) return;
    _watermarkEntry = OverlayEntry(
      builder: (context) {
        if (_isFullScreen) {
          return Positioned.fill(
            child: IgnorePointer(
              child: MovingWatermark(name: _userName, phone: _phoneNumber),
            ),
          );
        }

        final renderBox =
            _playerKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return const SizedBox.shrink();

        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        return Positioned(
          left: position.dx,
          top: position.dy,
          width: size.width,
          height: size.height,
          child: IgnorePointer(
            child: MovingWatermark(name: _userName, phone: _phoneNumber),
          ),
        );
      },
    );
    Overlay.of(context).insert(_watermarkEntry!);
  }

  // ───────────────────────────── build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    if (_isYoutube) return _buildYoutubeScaffold(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _watermarkEntry?.markNeedsBuild();
    });

    return Scaffold(
      backgroundColor: AppColors.videoPlayerBgColor,
      appBar: CustomAppBar(
        title: widget.title,
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildYoutubeScaffold(BuildContext context) {
    // In landscape YoutubePlayerBuilder renders the player over the whole
    // screen and discards the page body; an app bar above it would push the
    // full-height player down and clip it off the bottom.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final code = _youtubeErrorCode;
    return Scaffold(
      backgroundColor: AppColors.videoPlayerBgColor,
      appBar: isLandscape
          ? null
          : CustomAppBar(
              title: widget.title,
              centerTitle: true,
              titleColor: AppColors.white,
              backgroundColor: AppColors.videoPlayerBgColor,
            ),
      body: code != null
          ? _buildErrorView(
              message: _youtubeErrorMessage(code),
              onRetry: _youtubeErrorIsPermanent(code)
                  ? null
                  : () => setState(() {
                      _youtubeErrorCode = null;
                      _youtubeAttempt++;
                    }),
            )
          : _buildYoutubePlayerBody(isLandscape),
    );
  }

  /// Places the player in the page.
  ///
  /// Landscape gets it raw: `YoutubePlayerBuilder` claims the whole screen
  /// there and must not be boxed into anything.
  ///
  /// Portrait centres the player card and its control row as one block —
  /// left to itself the widget is content-sized (`MainAxisSize.min`) and the
  /// Scaffold pins it to the top of the body, leaving a tall band of dead
  /// space underneath. `crossAxisAlignment: stretch` keeps the width
  /// constraint tight, which is what the player card and the control Row's
  /// `Expanded` sized against before; a bare `Center` would loosen it.
  Widget _buildYoutubePlayerBody(bool isLandscape) {
    final player = CustomYoutubePlayer(
      key: ValueKey(_youtubeAttempt),
      videoUrl: _youtubeId ?? _effectiveUrl,
      autoPlay: true,
      onError: _onYoutubeError,
      onProgress: _trackingEnabled ? _onYoutubeProgress : null,
    );

    if (isLandscape) return player;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [player],
    );
  }

  Widget _buildErrorView({required String message, VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.alwaysWhite,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: Screen.getVerticalSize(16)),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.alwaysWhite),
      );
    }

    if (_error != null) {
      return _buildErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _initPlayer();
        },
      );
    }

    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
          return const SizedBox.shrink();
        }

        final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

        final Widget stack = Stack(
          key: _playerKey,
          fit: StackFit.loose,
          children: [
            PodVideoPlayer(
              controller: controller,
              backgroundColor: AppColors.videoPlayerBgColor,
              matchFrameAspectRatioToVideo: true,
              alwaysShowProgressBar: false,
              podProgressBarConfig: PodProgressBarConfig(
                playingBarColor: AppColors.primary,
                circleHandlerColor: AppColors.primary,
                bufferedBarColor: AppColors.primary.withValues(alpha: 0.3),
                backgroundColor: AppColors.grey200,
              ),
              onToggleFullScreen: (isFullScreen) async {
                // Resolved before the awaits: pod_player pushes/pops its own
                // fullscreen route while they run, so reading it afterwards
                // is a use-across-async-gap. It is the root navigator's
                // overlay either way.
                final overlay = Overlay.of(context);

                if (isFullScreen) {
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                  await SystemChrome.setEnabledSystemUIMode(
                    SystemUiMode.immersiveSticky,
                  );
                } else {
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                  await SystemChrome.setEnabledSystemUIMode(
                    SystemUiMode.manual,
                    overlays: SystemUiOverlay.values,
                  );
                }

                setState(() {
                  _isFullScreen = isFullScreen;
                });

                // Allow time for the new route to be pushed or popped by pod_player
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  if (_watermarkEntry != null) {
                    _watermarkEntry!.remove();
                    overlay.insert(_watermarkEntry!);
                    _watermarkEntry!.markNeedsBuild();
                  }
                });
              },
            ),
          ],
        );

        if (screenAspectRatio > _lastAspectRatio) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [stack],
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [stack],
          );
        }
      },
    );
  }
}
