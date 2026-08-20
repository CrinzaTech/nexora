import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/bloc/theme_cubit.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_list_tile.dart';

/// "Dark Mode" row in the profile page's Account Settings section —
/// same shape as every other tile, with a sun/moon badge in place of the
/// chevron.
///
/// Reads the live [ThemeCubit] rather than holding local state, so the
/// badge can't drift out of sync with the theme the app is actually
/// painting (e.g. under [ThemeMode.system], where the OS moves it).
class DarkModeTile extends StatelessWidget {
  const DarkModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        // Not `mode == ThemeMode.dark`: under ThemeMode.system the truth
        // is the platform brightness, and a badge showing a sun on a
        // dark screen would be plainly wrong.
        final isDark = mode.isDarkIn(context);

        return CustomProfileListTileWidget(
          title: "Dark Mode",
          leadingIcon: AppImages.themeModeIcon,
          // The whole row is the tap target, matching every other tile.
          // The badge is painted as a pure indicator so there's no nested
          // hit-test competing with it.
          onTap: () => context.read<ThemeCubit>().toggle(isCurrentlyDark: isDark),
          trailing: ThemeModeBadge(isDark: isDark),
        );
      },
    );
  }
}

/// Sun / moon indicator showing which mode is *currently* active — a sun
/// in light, a moon in dark — mirroring what the switch used to say with
/// its on/off position.
///
/// Each mode gets its own hue: the moon takes the brand indigo, the sun
/// takes the warm accent already used for the gilt edge on cards, so the
/// control belongs to the same palette rather than importing a stray
/// yellow.
class ThemeModeBadge extends StatelessWidget {
  final bool isDark;

  /// Purely decorative by default — the parent row owns the gesture.
  final VoidCallback? onTap;

  const ThemeModeBadge({super.key, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = isDark ? AppColors.primary : AppColors.accent;
    final size = Screen.getSize(34);

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withValues(alpha: isDark ? 0.18 : 0.14),
        border: Border.all(color: tone.withValues(alpha: 0.38), width: 1),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: isDark ? 0.30 : 0.22),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        // Sun and moon trade places on an arc rather than cross-fading in
        // situ — the small rotation is what makes it read as one control
        // changing state instead of two icons swapping.
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
          // The key is what tells AnimatedSwitcher this is a new child;
          // without it the icon swaps instantly with no transition.
          key: ValueKey(isDark),
          color: tone,
          size: Screen.getSize(18),
        ),
      ),
    );

    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}
