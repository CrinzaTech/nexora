import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:flutter/material.dart';

/// Tag shared by every avatar that opens the full-screen viewer.
/// Only one avatar can be on screen at a time per route, so a single
/// constant tag is enough to drive the Hero flight.
const String kProfileImageHeroTag = 'profile-image-hero';

/// Flight shuttle that un-rounds the avatar as it grows into the viewer
/// (and re-rounds it on the way back), so the circle→full-image transition
/// reads as one continuous shape instead of a hard pop.
Widget profileHeroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final hero = direction == HeroFlightDirection.push
      ? toHeroContext.widget as Hero
      : fromHeroContext.widget as Hero;

  // Push: circle → square. Pop: square → circle.
  final radiusTween = Tween<double>(begin: 1, end: 0);
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      final t = direction == HeroFlightDirection.push
          ? radiusTween.evaluate(curved)
          : 1 - radiusTween.evaluate(curved);
      final size = MediaQuery.sizeOf(context).shortestSide;
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.5 * t),
        child: hero.child,
      );
    },
  );
}

/// Wraps [child] in the Hero that flies into [ProfileImageViewer].
///
/// Use on the source avatar so the tap-to-open transition is continuous.
/// Pass `null` for [tag] to opt out (e.g. when there is no image).
class ProfileImageHero extends StatelessWidget {
  final String? tag;
  final Widget child;

  const ProfileImageHero({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) {
    if (tag == null) return child;
    return Hero(
      tag: tag!,
      flightShuttleBuilder: profileHeroFlightShuttleBuilder,
      child: child,
    );
  }
}

/// Opens [ProfileImageViewer] as a translucent full-screen route.
///
/// Does nothing when there is no image to show — callers can fire this
/// unconditionally from an avatar's `onTap`.
Future<void> showProfileImageViewer(
  BuildContext context, {
  String? imageUrl,
  File? imageFile,
  String? heroTag,
}) {
  final hasImage =
      imageFile != null || (imageUrl != null && imageUrl.isNotEmpty);
  if (!hasImage) return Future<void>.value();

  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => ProfileImageViewer(
        imageUrl: imageUrl,
        imageFile: imageFile,
        heroTag: heroTag ?? kProfileImageHeroTag,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Full-screen profile-picture viewer.
///
/// * Pinch to zoom (1x – 5x) and pan while zoomed.
/// * Double-tap toggles between fit and 2.5x, centred on the tap point.
/// * Tap the backdrop (only while un-zoomed) or the close button to dismiss.
/// * Swipe down while un-zoomed to dismiss.
class ProfileImageViewer extends StatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final String heroTag;

  const ProfileImageViewer({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.heroTag = kProfileImageHeroTag,
  });

  @override
  State<ProfileImageViewer> createState() => _ProfileImageViewerState();
}

class _ProfileImageViewerState extends State<ProfileImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;

  final TransformationController _controller = TransformationController();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  /// Drives the "swipe down to dismiss" translation + backdrop fade.
  double _dragOffset = 0;

  /// True whenever the image is zoomed past its resting scale — used to
  /// disable backdrop-tap and drag-to-dismiss so they don't fight panning.
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
    _animationController.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) _controller.value = value;
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTransformChanged)
      ..dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > _minScale + 0.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(begin: _controller.value, end: target)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward(from: 0);
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    // Zoom in around the tapped point so the detail under the finger stays put.
    // Built entry-by-entry (translate ∘ scale) to keep the maths explicit.
    final position = details.localPosition;
    const s = _doubleTapScale;
    _animateTo(
      Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(0, 3, -position.dx * (s - 1))
        ..setEntry(1, 3, -position.dy * (s - 1)),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() => _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 500));
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset > 120 || velocity > 700) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  ImageProvider? get _imageProvider {
    if (widget.imageFile != null) return FileImage(widget.imageFile!);
    final url = widget.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImageProvider(url, cacheKey: Utils.imageCacheKey(url));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;
    if (provider == null) return const SizedBox.shrink();

    // Backdrop fades out as the sheet is dragged away.
    final dragProgress = (_dragOffset / 300).clamp(0.0, 1.0);
    final backdropOpacity = 1 - dragProgress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Backdrop ────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _isZoomed ? null : () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.88 * backdropOpacity),
                ),
              ),
            ),
          ),

          // ── Image ───────────────────────────────────────────────
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTap,
                // The handler lives on onDoubleTapDown so we get the tap
                // position; this empty callback is what arms the recogniser.
                onDoubleTap: () {},
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: _handleDragEnd,
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  clipBehavior: Clip.none,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: Image(
                        image: provider,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _ViewerSpinner();
                        },
                        errorBuilder: (_, _, _) => const _ViewerError(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Close button ────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Opacity(
              opacity: backdropOpacity,
              child: Material(
                color: AppColors.alwaysWhite.withValues(alpha: 0.16),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: AppColors.alwaysWhite, size: 22),
                  ),
                ),
              ),
            ),
          ),

          // ── Hint ────────────────────────────────────────────────
          if (!_isZoomed)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Opacity(
                opacity: backdropOpacity,
                child: Text(
                  'Pinch or double-tap to zoom',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.alwaysWhite.withValues(alpha: 0.7),
                    fontSize: Screen.getFontSizeCapped(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerSpinner extends StatelessWidget {
  const _ViewerSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CircularProgressIndicator(color: AppColors.alwaysWhite, strokeWidth: 2),
    );
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.broken_image_outlined,
          color: AppColors.alwaysWhite.withValues(alpha: 0.7),
          size: 56,
        ),
        const SizedBox(height: 12),
        Text(
          'Could not load image',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.alwaysWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
