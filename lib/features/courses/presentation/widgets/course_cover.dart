import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/whole_image.dart';

/// A course banner, shown **whole**.
///
/// The artwork is whatever the educator uploaded — usually a wide
/// promotional banner with the branding and the syllabus down the edges
/// — while every surface that shows it is a fixed box: a 16:9 tile on
/// the home rail, a 160px header on a list card, a square thumbnail on a
/// row. `BoxFit.cover` filled those by cropping the edges off, so the
/// learner saw the middle third of the banner and none of what the
/// educator put on it.
///
/// [WholeImage] fits the banner inside the box instead and fills what's
/// left over with a blurred copy of itself, so nothing is cropped and a
/// banner that already matches the box looks exactly as it did.
class CourseCoverImage extends StatelessWidget {
  final String? url;

  /// Frame size. Leave `null` on either axis to be sized by the parent.
  final double? width;
  final double? height;

  final BorderRadius? borderRadius;

  /// Size of the placeholder glyph. Scale it down on small thumbnails.
  final double? fallbackIconSize;

  const CourseCoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return WholeImage(
      url: url,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fallback: Container(
        color: AppColors.grey100,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: AppColors.grey300,
          size: fallbackIconSize ?? Screen.getSize(28),
        ),
      ),
    );
  }
}

/// Opens the course banner full-screen — pinch to zoom, double-tap to
/// zoom in on a point, swipe down to dismiss.
///
/// Its own hero tag rather than the profile one: the learner's avatar
/// can be on screen at the same time, and a shared tag would fly the
/// banner out of the corner it sits in.
Future<void> showCourseCover(BuildContext context, String? url) =>
    showFullScreenImage(context, url, heroTag: 'course-cover');
