import 'package:nexora/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Text in the given colour, nudged — only as far as it has to be — until
/// it reads on the page behind it.
///
/// A white-label theme can pick any primary colour. A pale one, set as a
/// heading on a white page (or a dark one on the dark page), all but
/// vanishes. This keeps the colour's hue and saturation and shifts only its
/// lightness, so a theme that already reads is untouched and one that
/// doesn't still looks like the same brand.
class ReadableText extends StatelessWidget {
  final String text;

  /// The wanted style. Its `color` is the colour to keep readable.
  final TextStyle style;

  /// Minimum contrast ratio against the page. 4.5 is the usual bar for
  /// body-size text.
  final double minContrast;

  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const ReadableText(
    this.text, {
    super.key,
    required this.style,
    this.minContrast = 4.5,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final wanted = style.color ?? AppColors.textPrimary;
    return Text(
      text,
      style: style.copyWith(
        color: readableOn(AppColors.white, wanted, minContrast),
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// [color], shifted in lightness until it has [minContrast] against
  /// [background]. Dark on a light page, light on a dark page.
  static Color readableOn(Color background, Color color, double minContrast) {
    if (_contrast(background, color) >= minContrast) return color;
    final hsl = HSLColor.fromColor(color);
    final darken = background.computeLuminance() > 0.5;
    var lightness = hsl.lightness;
    for (var i = 0; i < 40; i++) {
      lightness = (lightness + (darken ? -0.02 : 0.02)).clamp(0.0, 1.0);
      final candidate = hsl.withLightness(lightness).toColor();
      if (_contrast(background, candidate) >= minContrast) return candidate;
    }
    // Hue can't carry it (e.g. saturated yellow): fall back to plain ink.
    return darken ? AppColors.black : AppColors.alwaysWhite;
  }
}
