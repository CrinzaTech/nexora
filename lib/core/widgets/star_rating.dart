import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';

/// Read-only star rating row supporting fractional values (e.g. 4.5).
///
/// Renders [count] stars using `star_rounded` for full stars,
/// `star_half_rounded` for halves, and `star_outline_rounded` for empties.
/// The threshold for showing a half-star is `>= i + 0.25 && < i + 0.75`.
class StarRating extends StatelessWidget {
  final double rating;
  final int count;
  final double size;
  final Color color;
  final Color emptyColor;
  final double spacing;

  const StarRating({
    super.key,
    required this.rating,
    this.count = 5,
    this.size = 16,
    this.color = AppColors.warning,
    this.emptyColor = AppColors.warning,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final delta = rating - i;
        final IconData icon;
        Color iconColor = color;
        if (delta >= 0.75) {
          icon = Icons.star_rounded;
        } else if (delta >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
          iconColor = emptyColor;
        }
        return Padding(
          padding: EdgeInsets.only(right: i == count - 1 ? 0 : spacing),
          child: Icon(icon, size: size, color: iconColor),
        );
      }),
    );
  }
}

/// Tappable star rating row supporting half-star selection.
///
/// Tapping the left half of a star sets `index + 0.5`, the right half sets
/// `index + 1.0`. The current value is rendered using the same
/// full/half/empty logic as [StarRating].
class InteractiveStarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;
  final int count;
  final double size;
  /// Nullable because the default falls back to brand-driven
  /// [AppColors.primary], which is now `static final` and can't be
  /// used as a const default. Resolved inside [build].
  final Color? filledColor;
  final Color? emptyColor;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment alignment;

  const InteractiveStarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.count = 5,
    this.size = 40,
    this.filledColor,
    // Null follows the theme (AppColors.mutedTextPrimary); it can't be
    // defaulted here because that token is a getter, not a constant.
    this.emptyColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    this.alignment = MainAxisAlignment.spaceBetween,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: List.generate(count, (i) {
        final delta = rating - i;
        final IconData icon;
        if (delta >= 0.75) {
          icon = Icons.star_rounded;
        } else if (delta >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        // filledColor is nullable (see field doc) — fall back to
        // the brand primary when the caller didn't pass one.
        final color = delta > 0
            ? (filledColor ?? AppColors.primary)
            : (emptyColor ?? AppColors.mutedTextPrimary);

        return _TappableStar(
          icon: icon,
          color: color,
          size: size,
          padding: padding,
          onTap: (isLeftHalf) =>
              onChanged(isLeftHalf ? i + 0.5 : i + 1.0),
        );
      }),
    );
  }
}

/// Single star with left/right half-tap detection.
class _TappableStar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final EdgeInsetsGeometry padding;
  final void Function(bool isLeftHalf) onTap;

  const _TappableStar({
    required this.icon,
    required this.color,
    required this.size,
    required this.padding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        // Account for the icon's left padding so the midpoint maps to the
        // visual centre of the star, not the centre of the gesture box.
        final paddingLeft =
            padding.resolve(Directionality.of(context)).left;
        final iconCenter = paddingLeft + size / 2;
        onTap(local.dx < iconCenter);
      },
      child: Padding(
        padding: padding,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
