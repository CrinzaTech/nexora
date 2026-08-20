import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/dm_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Row tile for one personal-chat thread — avatar + name + last message
/// preview, with a relative timestamp, an unread pill and a "Blocked"
/// chip on threads staff have closed.
class DmConversationTile extends StatelessWidget {
  final DmConversation conversation;
  final VoidCallback onTap;

  const DmConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final hasUnread = conversation.hasUnread;
    final preview = conversation.lastMessagePreview.trim();
    // Subtitle falls back to the staff member's role line on a thread
    // that's been opened but never used, so the row is never half-empty.
    final subtitle = preview.isNotEmpty
        ? preview
        : (conversation.otherUserSubtitle.isNotEmpty
              ? conversation.otherUserSubtitle
              : 'Start the conversation');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: Screen.getPadding(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DmAvatar(
              initials: conversation.initials,
              imageUrl: conversation.otherUserAvatarUrl,
              size: rh.isLargeScreen ? 100 : Screen.getSize(56),
            ),
            SizedBox(width: Screen.getHorizontalSize(10)),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherUserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: Screen.getFontSize(16),
                          ),
                        ),
                      ),
                      if (conversation.isBlocked) ...[
                        SizedBox(width: Screen.getHorizontalSize(6)),
                        const _BlockedChip(),
                      ],
                    ],
                  ),
                  SizedBox(height: Screen.getVerticalSize(2)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.grey400,
                      fontWeight: hasUnread
                          ? FontWeight.w500
                          : FontWeight.w400,
                      fontSize: Screen.getFontSize(12),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: Screen.getHorizontalSize(8)),

            // Trailing column: time above, unread pill below. Fixed
            // cross-axis alignment so rows with and without a pill keep
            // their timestamps on the same vertical line.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    _relativeTime(conversation.lastMessageAt!),
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: hasUnread ? AppColors.primary : AppColors.grey400,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: Screen.getFontSize(11),
                    ),
                  ),
                if (hasUnread) ...[
                  SizedBox(height: Screen.getVerticalSize(6)),
                  _UnreadPill(count: conversation.unreadCount),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-style stamp: clock time today, "Yesterday", weekday name
  /// inside the last week, then a short date.
  static String _relativeTime(DateTime raw) {
    final at = raw.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(at.year, at.month, at.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return DateFormat('h:mm a').format(at);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(at);
    return DateFormat('d MMM').format(at);
  }
}

class _UnreadPill extends StatelessWidget {
  final int count;

  const _UnreadPill({required this.count});

  @override
  Widget build(BuildContext context) {
    // Cap the label so a long-neglected thread can't stretch the row.
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: Screen.getSize(20)),
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(6),
        vertical: Screen.getVerticalSize(2),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(Screen.getSize(10)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.alwaysWhite,
          fontWeight: FontWeight.w700,
          fontSize: Screen.getFontSize(11),
        ),
      ),
    );
  }
}

class _BlockedChip extends StatelessWidget {
  const _BlockedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(8),
        vertical: Screen.getVerticalSize(2),
      ),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(Screen.getSize(8)),
      ),
      child: Text(
        'Closed',
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.grey400,
          fontWeight: FontWeight.w600,
          fontSize: Screen.getFontSize(10),
        ),
      ),
    );
  }
}
