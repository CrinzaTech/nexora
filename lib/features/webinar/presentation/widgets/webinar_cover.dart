import 'package:flutter/material.dart';

import 'package:nexora/core/widgets/whole_image.dart';

/// A webinar cover, shown **whole**.
///
/// Covers are uploaded at whatever shape the educator had — a portrait
/// poster, a square social graphic, a 16:9 still — and the card, the
/// detail header and the join screen are all 16:9 boxes. Filling those
/// with `BoxFit.cover` crops whatever doesn't fit, which on a portrait
/// poster means a band across the middle: the title and the date are
/// outside it, and the learner sees half an image.
///
/// [WholeImage] does the fitting: the cover sits inside the box and the
/// space it leaves over is filled with a blurred copy of itself.
class WebinarCoverImage extends StatelessWidget {
  final String? url;

  /// Drawn when there is no cover, or its presigned URL expired between
  /// the fetch and the render.
  final Widget fallback;

  const WebinarCoverImage({
    super.key,
    required this.url,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) =>
      WholeImage(url: url, fallback: fallback);
}

/// Opens the cover full-screen — pinch to zoom, double-tap, swipe down to
/// dismiss — the same viewer a profile picture opens into.
///
/// Its own hero tag rather than the profile one: an avatar is often on
/// screen at the same time, and sharing a tag would fly the cover out of
/// the learner's face in the corner.
Future<void> showWebinarCover(BuildContext context, String? url) =>
    showFullScreenImage(context, url, heroTag: 'webinar-cover');

/// The "there is more of this picture" affordance on a webinar cover.
class WebinarCoverExpandButton extends StatelessWidget {
  const WebinarCoverExpandButton({super.key});

  @override
  Widget build(BuildContext context) => const ImageExpandButton();
}
