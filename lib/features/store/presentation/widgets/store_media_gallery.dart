import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';

/// The product page's swipeable gallery: photos first (the first is the
/// cover), then the video. Tapping opens [StoreMediaViewer] full screen.
class StoreMediaGallery extends StatefulWidget {
  final List<StoreMedia> media;

  /// Shown when the product has no media at all.
  final String? fallbackImageUrl;

  const StoreMediaGallery({
    super.key,
    required this.media,
    this.fallbackImageUrl,
  });

  @override
  State<StoreMediaGallery> createState() => _StoreMediaGalleryState();
}

class _StoreMediaGalleryState extends State<StoreMediaGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<StoreMedia> get _media => widget.media.isNotEmpty
      ? widget.media
      : [
          if (widget.fallbackImageUrl != null)
            StoreMedia(isVideo: false, url: widget.fallbackImageUrl!),
        ];

  /// The video's poster: its own thumb, else the cover photo.
  String? _posterFor(StoreMedia m) =>
      m.thumbUrl ??
      widget.media.where((x) => !x.isVideo).firstOrNull?.url ??
      widget.fallbackImageUrl;

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoreMediaViewer(media: _media, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    if (media.isEmpty) {
      return ColoredBox(
        color: AppColors.grey100,
        child: Center(
          child: Icon(Icons.image_outlined, size: 56, color: AppColors.grey300),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.white,
          child: PageView.builder(
            controller: _controller,
            itemCount: media.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final m = media[i];
              return GestureDetector(
                onTap: () => _openViewer(i),
                child: m.isVideo
                    ? _VideoPoster(
                        posterUrl: _posterFor(m),
                        durationSec: m.durationSec,
                      )
                    : CustomNetworkImage(url: m.url, fit: BoxFit.contain),
              );
            },
          ),
        ),
        if (media.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < media.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.grey300.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        if (media.length > 1)
          Positioned(
            right: 14,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_page + 1}/${media.length}',
                style: AppTypography.bodyTextXtraSmallBold.copyWith(
                  color: AppColors.alwaysWhite,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoPoster extends StatelessWidget {
  final String? posterUrl;
  final double? durationSec;

  const _VideoPoster({this.posterUrl, this.durationSec});

  @override
  Widget build(BuildContext context) {
    final secs = durationSec?.round();
    return Stack(
      fit: StackFit.expand,
      children: [
        posterUrl != null
            ? CustomNetworkImage(url: posterUrl, fit: BoxFit.cover)
            : const ColoredBox(color: AppColors.videoPlayerBgColor),
        ColoredBox(color: AppColors.black.withValues(alpha: 0.25)),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alwaysWhite.withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 38,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
        if (secs != null && secs > 0)
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                style: AppTypography.bodyTextXtraSmallBold.copyWith(
                  color: AppColors.alwaysWhite,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen media: pinch-to-zoom photos and the product video.
class StoreMediaViewer extends StatefulWidget {
  final List<StoreMedia> media;
  final int initialIndex;

  const StoreMediaViewer({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  @override
  State<StoreMediaViewer> createState() => _StoreMediaViewerState();
}

class _StoreMediaViewerState extends State<StoreMediaViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const onDark = AppColors.alwaysWhite;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: onDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: onDark),
        ),
        title: Text(
          '${_page + 1} of ${widget.media.length}',
          style: AppTypography.bodyTextLargeSemiBold.copyWith(color: onDark),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) {
          final m = widget.media[i];
          if (m.isVideo) {
            // Only the visible page holds a player, so swiping away stops it.
            return i == _page
                ? _ProductVideo(url: m.url)
                : const SizedBox.shrink();
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CustomNetworkImage(url: m.url, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

class _ProductVideo extends StatefulWidget {
  final String url;

  const _ProductVideo({required this.url});

  @override
  State<_ProductVideo> createState() => _ProductVideoState();
}

class _ProductVideoState extends State<_ProductVideo> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text(
          'This video can’t be played right now.',
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.alwaysWhite,
          ),
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.alwaysWhite),
      );
    }
    return GestureDetector(
      onTap: () => setState(
        () => _controller.value.isPlaying
            ? _controller.pause()
            : _controller.play(),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (_, value, _) => AnimatedOpacity(
              opacity: value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 40,
                  color: AppColors.alwaysWhite,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.alwaysWhite,
                bufferedColor: AppColors.alwaysWhite.withValues(alpha: 0.35),
                backgroundColor: AppColors.alwaysWhite.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
