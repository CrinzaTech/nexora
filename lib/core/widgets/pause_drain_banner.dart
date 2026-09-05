import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';

/// Shown over the player while the host's last words drain out of the
/// buffer after a pause. Students run ~7s behind the host, so the
/// `classPaused` signal arrives while the final sentence is still in
/// flight — the player keeps going until it reaches the end of the
/// stream, and only then does the waiting screen take over. No spinner,
/// no screen change: nothing is wrong, the class is just finishing.
class PauseDrainBanner extends StatelessWidget {
  const PauseDrainBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.alwaysWhite,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'The host is pausing — finishing what was said…',
              style: AppTypography.bodyTextSemiBold.copyWith(
                color: AppColors.alwaysWhite,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
