import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/profile_image_viewer.dart';

/// Artwork shown **whole**, inside a frame of a fixed shape.
///
/// Educators upload at whatever shape they had — a portrait poster, a
/// square social graphic, a wide banner — while the surfaces that show
/// it (cards, list rows, detail headers) are boxes of a fixed shape.
/// Filling those with [BoxFit.cover] crops away whatever doesn't fit,
/// which on a wide banner means the left and right edges — usually the
/// half with the branding on it — never reach the learner.
///
/// So the image is fitted *inside* the box with [BoxFit.contain], and
/// the space that fit leaves over is filled with a blurred, slightly
/// darkened copy of the same image. Nothing is cropped, nothing is
/// letterboxed onto dead grey, and artwork that already matches the box
/// looks exactly as it did — the blur is only ever visible where the
/// crop used to eat the picture.
///
/// The backdrop is the same URL, so it costs one download and a cache
/// hit: [CustomNetworkImage] keys its cache on the URL with the S3
/// signature stripped, which is what makes the second read free.
class WholeImage extends StatelessWidget {
  final String? url;

  /// Drawn when there is no image, or its presigned URL expired between
  /// the fetch and the render.
  final Widget fallback;

  /// Frame size. Leave `null` on either axis to be sized by the parent
  /// (an [AspectRatio], an [Expanded], a stretched [Row] child…).
  final double? width;
  final double? height;

  /// Rounds the frame — both the artwork and its backdrop.
  final BorderRadius? borderRadius;

  /// How soft the backdrop is. The default reads as texture rather than
  /// a second, smaller copy of the picture.
  final double blurSigma;

  /// Settles the blur so a bright image doesn't wash out whatever sits
  /// on top of it (badges, an expand button). Pass `0` for none.
  final double scrimOpacity;

  const WholeImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.borderRadius,
    this.blurSigma = 18,
    this.scrimOpacity = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    final src = url;

    Widget child = (src == null || src.isEmpty)
        ? fallback
        : Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: CustomNetworkImage(
                    url: src,
                    fit: BoxFit.cover,
                    // A blurred backdrop has nothing to say on its own:
                    // when the image fails, the foreground's fallback is
                    // the whole answer.
                    errorWidget: const SizedBox.shrink(),
                    placeholder: const SizedBox.shrink(),
                  ),
                ),
              ),
              if (scrimOpacity > 0)
                ColoredBox(
                  color: AppColors.black.withValues(alpha: scrimOpacity),
                ),
              CustomNetworkImage(
                url: src,
                fit: BoxFit.contain,
                errorWidget: fallback,
              ),
            ],
          );

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}

/// Opens [url] full-screen — pinch to zoom, double-tap, swipe down to
/// dismiss — in the same viewer a profile picture opens into.
///
/// [heroTag] should be unique to the surface that opens it: an avatar is
/// often on screen at the same time, and sharing the profile tag would
/// fly the picture out of the learner's face in the corner.
Future<void> showFullScreenImage(
  BuildContext context,
  String? url, {
  required String heroTag,
}) => showProfileImageViewer(context, imageUrl: url, heroTag: heroTag);

/// The "there is more of this picture" affordance.
///
/// Banner artwork is not obviously tappable — an avatar has years of
/// convention behind it and a 16:9 banner has none — so the surfaces
/// that open the full view say so with this.
class ImageExpandButton extends StatelessWidget {
  const ImageExpandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(28);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(
          color: AppColors.alwaysWhite.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(
        Icons.fullscreen_rounded,
        size: Screen.getSize(17),
        color: AppColors.alwaysWhite,
      ),
    );
  }
}
