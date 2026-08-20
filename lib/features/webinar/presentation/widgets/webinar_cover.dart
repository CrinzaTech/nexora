import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/profile_image_viewer.dart';

/// A webinar cover, shown **whole**.
///
/// Covers are uploaded at whatever shape the educator had — a portrait
/// poster, a square social graphic, a 16:9 still — and the card, the
/// detail header and the join screen are all 16:9 boxes. Filling those
/// with `BoxFit.cover` crops whatever doesn't fit, which on a portrait
/// poster means a band across the middle: the title and the date are
/// outside it, and the learner sees half an image.
///
/// So the image is fitted *inside* the box instead, and the empty space
/// is filled with a blurred, darkened copy of the same image. Nothing is
/// cropped, nothing is letterboxed onto dead grey, and a cover that is
/// already 16:9 looks exactly as it did — the blur is only ever visible
/// where the crop used to eat the picture.
class WebinarCoverImage extends StatelessWidget {
  final String? url;

  /// Drawn when there is no cover, or its presigned URL expired between
  /// the fetch and the render.
  final Widget fallback;

  const WebinarCoverImage({super.key, required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The backdrop. Same URL, so it is one download and a cache hit
        // — `CustomNetworkImage` keys its cache on the URL with the S3
        // signature stripped, which is what makes the second read free.
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: CustomNetworkImage(
              url: src,
              fit: BoxFit.cover,
              // A blurred backdrop has nothing to say on its own: when
              // the image fails, the foreground's fallback is the whole
              // answer.
              errorWidget: const SizedBox.shrink(),
              placeholder: const SizedBox.shrink(),
            ),
          ),
        ),
        // Settles the blur so a bright cover doesn't wash out the badges
        // sitting on top of it.
        ColoredBox(color: AppColors.black.withValues(alpha: 0.18)),
        CustomNetworkImage(url: src, fit: BoxFit.contain, errorWidget: fallback),
      ],
    );
  }
}

/// Opens the cover full-screen — pinch to zoom, double-tap, swipe down to
/// dismiss — the same viewer a profile picture opens into.
///
/// Its own hero tag rather than the profile one: an avatar is often on
/// screen at the same time, and sharing a tag would fly the cover out of
/// the learner's face in the corner.
Future<void> showWebinarCover(BuildContext context, String? url) =>
    showProfileImageViewer(context, imageUrl: url, heroTag: 'webinar-cover');

/// The "there is more of this picture" affordance.
///
/// A cover is not obviously tappable — an avatar has years of convention
/// behind it and a 16:9 banner has none — so the surfaces that open the
/// full view say so with this.
class WebinarCoverExpandButton extends StatelessWidget {
  const WebinarCoverExpandButton({super.key});

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
        border: Border.all(color: AppColors.alwaysWhite.withValues(alpha: 0.24)),
      ),
      child: Icon(
        Icons.fullscreen_rounded,
        size: Screen.getSize(17),
        color: AppColors.alwaysWhite,
      ),
    );
  }
}
