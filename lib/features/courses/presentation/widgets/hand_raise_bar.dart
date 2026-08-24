import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/presentation/bloc/live_class_cubit.dart';

/// Raise-hand → speak control, mirroring the server-side state machine
/// ([HandPhase]). Audio-only: the student publishes a mic when granted,
/// never video.
///
/// Rendered as a floating action button rather than a full-width bar —
/// the bar cost a whole row of vertical space, which landscape doesn't
/// have to spare. Phase detail that used to sit in the button label now
/// lives in the tooltip, with the queue position as a badge.
class HandRaiseFab extends StatelessWidget {
  final LiveClassState state;
  final int? myId;

  /// Compact variant, for the landscape speed dial.
  final bool mini;

  const HandRaiseFab({
    super.key,
    required this.state,
    required this.myId,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LiveClassCubit>();
    final spec = _specFor(cubit, state.flags);

    final background = spec.onTap == null
        ? spec.color.withValues(alpha: 0.5)
        : spec.color;
    final child = spec.showSpinner
        ? SizedBox(
            width: AppSizes.iconS,
            height: AppSizes.iconS,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.alwaysWhite,
            ),
          )
        : Icon(spec.icon);

    // Two live-class routes can co-exist during a fullscreen push; a
    // stable non-default tag keeps Hero from throwing on duplicates.
    const heroTag = 'live-class-hand-raise';
    final Widget fab = mini
        ? FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: spec.onTap,
            backgroundColor: background,
            foregroundColor: AppColors.alwaysWhite,
            tooltip: spec.tooltip,
            child: child,
          )
        : FloatingActionButton(
            heroTag: heroTag,
            onPressed: spec.onTap,
            backgroundColor: background,
            foregroundColor: AppColors.white,
            tooltip: spec.tooltip,
            child: child,
          );

    final position = state.queuePosition;
    if (state.handPhase == HandPhase.queued && position != null) {
      return Badge(
        label: Text('$position'),
        backgroundColor: AppColors.primary,
        child: fab,
      );
    }
    return fab;
  }

  _FabSpec _specFor(LiveClassCubit cubit, MyFlags flags) {
    // Hand-blocked → disabled affordance, host took the control away.
    if (flags.handBlocked) {
      return _FabSpec(
        icon: Icons.back_hand_outlined,
        color: AppColors.grey300,
        tooltip: 'Raising hand disabled by host',
        onTap: null,
      );
    }

    switch (state.handPhase) {
      case HandPhase.idle:
        // Mic-blocked (but not hand-blocked): allow raising as a signal;
        // the server refuses the mic, so we never reach speaking.
        return _FabSpec(
          icon: Icons.back_hand,
          color: AppColors.primary,
          tooltip: flags.micBlocked
              ? 'Raise hand (audio disabled by host)'
              : 'Raise hand',
          onTap: cubit.raiseHand,
        );

      case HandPhase.queued:
        final pos = state.queuePosition;
        return _FabSpec(
          icon: Icons.back_hand_outlined,
          color: AppColors.mutedTextPrimary,
          tooltip: pos != null
              ? 'Hand raised · position $pos. Tap to lower'
              : 'Hand raised. Tap to lower',
          onTap: cubit.lowerHand,
        );

      case HandPhase.granted:
        return _FabSpec(
          icon: Icons.mic_none,
          color: AppColors.primary,
          tooltip: 'Connecting… speak now',
          onTap: null,
          showSpinner: true,
        );

      case HandPhase.connecting:
        return _FabSpec(
          icon: Icons.mic_none,
          color: AppColors.primary,
          tooltip: 'Connecting…',
          onTap: null,
          showSpinner: true,
        );

      case HandPhase.speaking:
        return _FabSpec(
          icon: Icons.stop_circle,
          color: AppColors.error,
          tooltip: "You're live. Tap to finish",
          onTap: cubit.stopSpeaking,
        );
    }
  }
}

class _FabSpec {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final bool showSpinner;

  const _FabSpec({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.showSpinner = false,
  });
}

/// Passive "someone else has the mic" indicator. Overlaid on the video
/// stage now that there's no control bar to host it.
class SpeakingChip extends StatelessWidget {
  final String name;

  const SpeakingChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: AppSizes.iconS, color: AppColors.alwaysWhite),
          SizedBox(width: Screen.getHorizontalSize(6)),
          Flexible(
            child: Text(
              '$name is speaking…',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(color: AppColors.alwaysWhite),
            ),
          ),
        ],
      ),
    );
  }
}
