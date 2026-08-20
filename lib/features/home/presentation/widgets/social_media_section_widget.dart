import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Social-media link bar shown at the bottom of the Home page, beneath the
/// "What Other Learners Say" reviews section.
///
/// Renders a horizontal row of icon + label tiles. Each tile opens the
/// platform's URL in the in-app [WebViewerPage] on tap.
class SocialMediaSectionWidget extends StatelessWidget {
  final List<SocialMediaLink> links;

  const SocialMediaSectionWidget({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────
        Padding(
          padding: Screen.getPadding(horizontal: 20),
          child: Text(
            'Follow Us',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h5SemiBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: Screen.getFontSizeCapped(20),
            ),
          ),
        ),

        SizedBox(height: Screen.getSize(16)),

        // ── Icon row ──────────────────────────────────────────────
        SizedBox(
          height: Screen.getSize(110),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: Screen.getPadding(horizontal: 20),
            itemCount: links.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: Screen.getSize(16)),
            itemBuilder: (context, index) =>
                _SocialIcon(link: links[index]),
          ),
        ),
      ],
    );
  }
}

/// Single social-media icon tile — circular icon with title label below.
class _SocialIcon extends StatelessWidget {
  final SocialMediaLink link;

  const _SocialIcon({required this.link});

  @override
  Widget build(BuildContext context) {
    final double iconSize = Screen.getSize(56);

    return GestureDetector(
      onTap: () async {
        if (link.link.isEmpty) return;
        final uri = Uri.parse(link.link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: SizedBox(
        width: Screen.getSize(80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Circle icon ─────────────────────────────────────
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: link.icon.isNotEmpty
                    ? CustomNetworkImage(
                        url: link.icon,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.cover,
                        errorWidget: _FallbackIcon(title: link.title),
                      )
                    : _FallbackIcon(title: link.title),
              ),
            ),

            SizedBox(height: Screen.getSize(8)),

            // ── Title label ──────────────────────────────────────
            Text(
              link.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the icon URL is missing or fails to load.
/// Renders the first letter of the platform title on a gradient circle.
class _FallbackIcon extends StatelessWidget {
  final String title;

  const _FallbackIcon({required this.title});

  @override
  Widget build(BuildContext context) {
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: AppColors.primary,
          fontSize: Screen.getFontSize(20),
        ),
      ),
    );
  }
}
