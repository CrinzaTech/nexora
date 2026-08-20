import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar for the person on the other end of a personal chat.
///
/// Staff have no image on the learner side — the backend's `users`
/// table has no image column — so [imageUrl] is null in practice and
/// the initials branch is what actually renders. The network branch
/// exists so the widget keeps working if avatars are added later.
class DmAvatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final double size;

  const DmAvatar({
    super.key,
    required this.initials,
    required this.size,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url != null && url.isNotEmpty)
            ? CustomNetworkImage(
                url: url,
                fit: BoxFit.cover,
                errorWidget: _initialsBlock(),
              )
            : _initialsBlock(),
      ),
    );
  }

  Widget _initialsBlock() {
    return Container(
      // A little more body in the dark theme — the 12 % wash that reads
      // as a soft tint on white all but disappears against near-black.
      color: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.28 : 0.12,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          // Scale the glyph with the circle so one widget serves the
          // 56 dp inbox row, the 46 dp AppBar and the web layouts.
          //
          // Deliberately NOT run through `Screen.getFontSize`: `size`
          // arrives already in final logical pixels, so scaling again
          // would double-apply the phone factor — invisible at a 360 dp
          // basis, but oversized anywhere wider.
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
