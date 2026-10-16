import 'package:nexora/core/router/app_router.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pieces shared by the Home popup, the panel card and the detail page, so
/// one post reads the same wherever it is opened.

/// Chip colours match the web admin's list.
Color newsTypeColor(NewsType type) => switch (type) {
  NewsType.news => const Color(0xFF2196F3),
  NewsType.update => const Color(0xFF4361EE),
  NewsType.offer => const Color(0xFF00AB55),
  NewsType.event => const Color(0xFF805DCA),
  NewsType.important => const Color(0xFFE7515A),
};

class NewsTypeChip extends StatelessWidget {
  final NewsType type;

  const NewsTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = newsTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
          color: color,
          fontSize: Screen.getFontSizeCapped(11),
          height: 1.2,
        ),
      ),
    );
  }
}

/// "Just now" · "5m ago" · "2h ago" · "Yesterday" · "3d ago" · "12 Oct".
String newsRelativeTime(DateTime at) {
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';
  return _shortDate(at, withYear: at.year != now.year);
}

/// "Ends today" · "Ends 22 Oct". Null for a permanent post.
String? newsExpiryText(DateTime? expiresAt) {
  if (expiresAt == null) return null;
  final now = DateTime.now();
  if (expiresAt.year == now.year &&
      expiresAt.month == now.month &&
      expiresAt.day == now.day) {
    return 'Ends today';
  }
  return 'Ends ${_shortDate(expiresAt, withYear: expiresAt.year != now.year)}';
}

String _shortDate(DateTime d, {required bool withYear}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final base = '${d.day} ${months[d.month - 1]}';
  return withYear ? '$base ${d.year}' : base;
}

/// "2h ago · Ends 22 Oct".
String newsTimeLine(NewsItem item) {
  final ends = newsExpiryText(item.expiresAt);
  final published = newsRelativeTime(item.publishedAt);
  return ends == null ? published : '$published · $ends';
}

/// Chip, time, title and the full message — everything but the image and
/// the button. The message is plain text and keeps its line breaks.
class NewsPostBody extends StatelessWidget {
  final NewsItem item;

  const NewsPostBody({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NewsTypeChip(type: item.type),
            Text(
              newsTimeLine(item),
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSizeCapped(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          style: AppTypography.h6SemiBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: Screen.getFontSizeCapped(18),
            height: 1.3,
          ),
        ),
        if (item.message.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            item.message,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: Screen.getFontSizeCapped(14),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 16:9 cover image. Draws nothing when the post has none.
class NewsPostImage extends StatelessWidget {
  final NewsItem item;
  final BorderRadius? borderRadius;

  const NewsPostImage({super.key, required this.item, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    if (!item.hasImage) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CustomNetworkImage(
        url: item.imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Full-width button for a post with an action. Draws nothing for
/// [NewsActionType.none].
class NewsActionButton extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onPressed;

  const NewsActionButton({
    super.key,
    required this.item,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!item.hasAction) return const SizedBox.shrink();
    // A minimum height rather than a fixed one, with the theme's tall
    // vertical padding trimmed: a fixed 48 clipped the bottom of the label
    // once the theme padding and the scaled font were added up.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
        ),
        icon: Icon(
          item.actionType == NewsActionType.externalLink
              ? Icons.open_in_new_rounded
              : Icons.arrow_forward_rounded,
          size: 18,
        ),
        label: Text(
          item.buttonLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyTextLargeSemiBold.copyWith(
            color: AppColors.onPrimary,
            fontSize: Screen.getFontSizeCapped(15),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Runs a post's button. A course opens the same course page a course push
/// does — the page itself decides between buy and continue. Routes through
/// [AppRouter.router] so it still works after the popup that started it
/// has closed.
Future<void> runNewsAction(BuildContext context, NewsItem item) async {
  final value = item.actionValue?.trim() ?? '';
  switch (item.actionType) {
    case NewsActionType.externalLink:
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) return;
      var opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        Utils.debugLog('News: launchUrl($value) failed: $e');
      }
      if (!opened && context.mounted) {
        CustomSnackbar.error(
          context,
          title: 'Could not open link',
          message: value,
        );
      }
      return;
    case NewsActionType.course:
      final courseId = int.tryParse(value);
      if (courseId == null) return;
      AppRouter.router.push('${AppRoutes.courseDetail}?courseId=$courseId');
      return;
    case NewsActionType.none:
      return;
  }
}
