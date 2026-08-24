import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';

/// Raise-hand → speak control for a webinar attendee.
///
/// Audio only: an attendee publishes a microphone when the host grants
/// it and never a camera. One button whose meaning follows the server's
/// state machine — raise, lower, then finish — with the queue position
/// as a badge rather than a label, so it stays the same size throughout.
class WebinarHandRaiseFab extends StatelessWidget {
  final WebinarRoomState state;

  /// Compact variant, for the landscape speed dial where several
  /// buttons share a column.
  final bool mini;

  const WebinarHandRaiseFab({
    super.key,
    required this.state,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WebinarRoomCubit>();
    final spec = _specFor(cubit);

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

    // A stable tag: a fullscreen player push can briefly mount two
    // routes carrying this button, and Hero throws on duplicates.
    const heroTag = 'webinar-hand-raise';
    final fab = mini
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
            foregroundColor: AppColors.alwaysWhite,
            tooltip: spec.tooltip,
            child: child,
          );

    final position = state.queuePosition;
    if (state.handPhase == WebinarHandPhase.queued && position != null) {
      return Badge(
        label: Text('$position'),
        backgroundColor: AppColors.primary,
        child: fab,
      );
    }
    return fab;
  }

  _FabSpec _specFor(WebinarRoomCubit cubit) {
    final flags = state.flags;

    // The host took the control away entirely — shown disabled rather
    // than hidden, so a returning attendee can tell the difference
    // between "not offered here" and "turned off for me".
    if (flags.handBlocked) {
      // Not `const`: the grey tokens are theme-driven getters, so they
      // resolve at runtime rather than at compile time.
      return _FabSpec(
        icon: Icons.back_hand_outlined,
        color: AppColors.grey400,
        tooltip: 'Raising hands is turned off by the host',
        onTap: null,
      );
    }

    switch (state.handPhase) {
      case WebinarHandPhase.idle:
        return _FabSpec(
          icon: Icons.back_hand,
          color: AppColors.primary,
          // Mic-blocked but not hand-blocked: raising is still a useful
          // signal to the host, and the server simply won't grant the
          // mic — so the button works and the tooltip is honest.
          tooltip: flags.micBlocked
              ? 'Raise hand (your mic is off)'
              : 'Raise hand',
          onTap: cubit.raiseHand,
        );

      case WebinarHandPhase.queued:
        final pos = state.queuePosition;
        return _FabSpec(
          icon: Icons.back_hand_outlined,
          color: AppColors.mutedTextPrimary,
          tooltip: pos != null
              ? 'Hand raised · position $pos. Tap to lower'
              : 'Hand raised. Tap to lower',
          onTap: cubit.lowerHand,
        );

      case WebinarHandPhase.granted:
      case WebinarHandPhase.connecting:
        return _FabSpec(
          icon: Icons.mic_none,
          color: AppColors.primary,
          tooltip: 'Connecting your microphone…',
          onTap: null,
          showSpinner: true,
        );

      case WebinarHandPhase.speaking:
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

/// "You're live" / "Asha is speaking" — overlaid on the stage so the
/// room can see who has the floor without a control bar to host it.
class WebinarSpeakingChip extends StatelessWidget {
  final String name;
  final bool isMe;

  const WebinarSpeakingChip({super.key, required this.name, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.error.withValues(alpha: 0.9)
            : AppColors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMe ? Icons.mic : Icons.graphic_eq,
            size: AppSizes.iconS,
            color: AppColors.alwaysWhite,
          ),
          SizedBox(width: Screen.getHorizontalSize(6)),
          Flexible(
            child: Text(
              isMe ? "You're live" : '$name is speaking…',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.alwaysWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
