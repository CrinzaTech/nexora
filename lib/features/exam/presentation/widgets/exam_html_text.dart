import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';

/// Renders exam question / instruction HTML (`<p>`, `<ul><li>`, `<b>`, …).
///
/// A single choke-point so styling and the plain-text fallback live in one
/// place. Images embedded in the HTML are unsupported in this version (a
/// deliberate v1 scope cut) — the `<img>` simply doesn't render.
class ExamHtmlText extends StatelessWidget {
  final String html;
  final TextStyle? baseStyle;
  final Color? color;

  const ExamHtmlText(
    this.html, {
    super.key,
    this.baseStyle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final style = (baseStyle ?? AppTypography.bodyTextLargeMedium).copyWith(
      color: color ?? AppColors.textPrimary,
    );

    // Fast path: plain text (no tags) avoids the HTML parser entirely.
    if (!trimmed.contains('<')) {
      return Text(trimmed, style: style);
    }

    return HtmlWidget(
      trimmed,
      textStyle: style,
      // Strip images — unsupported this version.
      customWidgetBuilder: (element) =>
          element.localName == 'img' ? const SizedBox.shrink() : null,
    );
  }
}
