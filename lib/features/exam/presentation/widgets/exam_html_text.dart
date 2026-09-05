import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';

/// Base for resolving root-relative asset paths in question HTML.
///
/// The admin panel embeds diagrams as `<img src="/Take/question-image?key=…">`
/// inside the question text. That endpoint lives on the media host, which
/// 302s to a presigned S3 URL — it is *not* on BASE_URL, which 404s for it.
/// Absolute `src` values ignore this and resolve as-is.
final Uri? _htmlBaseUri = () {
  final base = (dotenv.env['MEDIA_BASE_URL']?.trim().isNotEmpty ?? false)
      ? dotenv.env['MEDIA_BASE_URL']!.trim()
      : (dotenv.env['BASE_URL'] ?? '').trim();
  if (base.isEmpty) return null;
  return Uri.tryParse(base.endsWith('/') ? base : '$base/');
}();

/// Renders exam question / instruction HTML (`<p>`, `<ul><li>`, `<b>`,
/// `<img>`, …).
///
/// A single choke-point so styling, image handling and the plain-text
/// fallback live in one place.
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
      baseUrl: _htmlBaseUri,
      onLoadingBuilder: (_, _, _) => const _ImagePending(),
      // A question's diagram often *is* the question, so a failure has to
      // say so — a silent gap reads as "this question has no image".
      onErrorBuilder: (_, element, _) =>
          element.localName == 'img' ? const _ImageFailed() : null,
    );
  }
}

class _ImagePending extends StatelessWidget {
  const _ImagePending();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.dividerLight),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ImageFailed extends StatelessWidget {
  const _ImageFailed();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 18, color: AppColors.errorDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "This question's image could not be loaded. Check your "
              'connection.',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.errorDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
