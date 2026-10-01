import 'package:nexora/core/wallpaper/wallpaper_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// True while a background (theme or custom) is showing — false for "None".
/// Rebuilds the caller when it changes, so a surface can turn translucent
/// (or a chip solid) only when there is a picture underneath it.
bool hasWallpaper(BuildContext context) =>
    context.select<WallpaperCubit, bool>((cubit) => cubit.state != null);

/// Paints the student's background photo behind [child], under a wash of
/// [scrimColor] so whatever sits on top stays readable.
///
/// The photo is fixed while [child] scrolls over it. With no background
/// set this is just [child] — no extra layers.
class WallpaperBackdrop extends StatelessWidget {
  final Widget child;

  /// The page colour the photo is washed towards — pass the surface the
  /// screen would otherwise show, so the photo reads as a tint of the
  /// page rather than a picture pasted behind it.
  final Color scrimColor;

  /// How much of [scrimColor] covers the photo, 0 → 1.
  final double scrimOpacity;

  const WallpaperBackdrop({
    super.key,
    required this.child,
    required this.scrimColor,
    this.scrimOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasWallpaper(context)) return child;
    return Stack(
      // Passthrough: [child] gets exactly the constraints it would have
      // had without the backdrop, so wrapping a page body can't move it.
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: WallpaperLayer(
            scrimColor: scrimColor,
            scrimOpacity: scrimOpacity,
          ),
        ),
        child,
      ],
    );
  }
}

/// The photo painted as a plain background *decoration* behind [child],
/// with no extra layer in the tree. Use it where [child] is a scroll view
/// that must keep its original widget structure (a `Stack` around a
/// NestedScrollView has thrown hit-test errors), and pair it with a
/// transparent Scaffold. Just [child] when no background is set.
class WallpaperDecorated extends StatelessWidget {
  final Widget child;
  final Color scrimColor;
  final double scrimOpacity;

  const WallpaperDecorated({
    super.key,
    required this.child,
    required this.scrimColor,
    this.scrimOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final image = context.watch<WallpaperCubit>().state;
    if (image == null) return child;
    return DecoratedBox(
      position: DecorationPosition.background,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: image,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            scrimColor.withValues(alpha: scrimOpacity),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// Just the photo and its scrim, filling its parent — for a screen that
/// already has a [Stack] to drop it into as the bottom layer. Paints
/// nothing with no background set.
class WallpaperLayer extends StatelessWidget {
  final Color scrimColor;
  final double scrimOpacity;

  const WallpaperLayer({
    super.key,
    required this.scrimColor,
    this.scrimOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final image = context.watch<WallpaperCubit>().state;
    if (image == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _WallpaperImage(image: image),
          ColoredBox(color: scrimColor.withValues(alpha: scrimOpacity)),
        ],
      ),
    );
  }
}

/// The background photo as a cover band that fades into [fadeTo] at its
/// bottom edge — a "cover photo" across the top of a page. Collapses to
/// nothing with no background set.
class WallpaperCover extends StatelessWidget {
  final double height;
  final Color fadeTo;

  /// How much of [fadeTo] veils the photo at the top, and from the middle
  /// down before the final fade. Raise both where text sits straight on
  /// the photo rather than on cards.
  final double topVeil;
  final double midVeil;

  const WallpaperCover({
    super.key,
    required this.height,
    required this.fadeTo,
    this.topVeil = 0.25,
    this.midVeil = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    final image = context.watch<WallpaperCubit>().state;
    if (image == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _WallpaperImage(image: image),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // A light veil up top keeps the status bar icons and
                  // the card's edge legible over a busy photo; the bottom
                  // runs out into the page colour so there is no seam.
                  colors: [
                    fadeTo.withValues(alpha: topVeil),
                    fadeTo.withValues(alpha: midVeil),
                    fadeTo,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperImage extends StatelessWidget {
  final ImageProvider image;

  const _WallpaperImage({required this.image});

  @override
  Widget build(BuildContext context) {
    // Own layer: the content scrolling above repaints every frame, the
    // photo never does.
    return RepaintBoundary(
      child: Image(
        image: image,
        fit: BoxFit.cover,
        // Keep the old photo on screen while a replacement decodes,
        // rather than flashing the bare page in between.
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        // A file that vanished underneath us (storage cleared mid-session)
        // degrades to the default page, not a broken-image glyph.
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
