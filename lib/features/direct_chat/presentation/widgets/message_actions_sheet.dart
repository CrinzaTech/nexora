import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:flutter/material.dart';

/// What the learner picked from the long-press menu.
enum MessageAction { reply, edit, delete }

/// Long-press menu for a single message bubble.
///
/// **Built at the moment it opens, never cached.** `canEdit` and
/// `canDelete` read the clock, so a menu constructed once on render
/// would still be offering Edit ten minutes after the 2-minute window
/// shut. Calling [show] per long-press is what keeps them honest.
class MessageActionsSheet extends StatelessWidget {
  final ChatMessage message;

  /// False when the thread is blocked — replying and editing both end
  /// in a send the server will refuse, so neither is offered.
  final bool canReply;

  const MessageActionsSheet({
    super.key,
    required this.message,
    required this.canReply,
  });

  /// Returns the chosen action, or null if dismissed.
  ///
  /// Resolves to null without showing anything when the message has no
  /// available actions at all — an educator's bubble in a blocked
  /// thread — so a long-press there is simply inert rather than opening
  /// an empty sheet.
  static Future<MessageAction?> show(
    BuildContext context, {
    required ChatMessage message,
    required bool canReply,
  }) {
    final hasAnyAction = canReply || message.canEdit || message.canDelete;
    if (!hasAnyAction) return Future<MessageAction?>.value();
    return showModalBottomSheet<MessageAction>(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Screen.getSize(20)),
        ),
      ),
      builder: (_) =>
          MessageActionsSheet(message: message, canReply: canReply),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: Screen.getVerticalSize(10)),
          Container(
            width: Screen.getHorizontalSize(40),
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(8)),
          if (canReply)
            _ActionRow(
              icon: Icons.reply_rounded,
              label: 'Reply',
              onTap: () => Navigator.of(context).pop(MessageAction.reply),
            ),
          // Author-only, text-only, inside the 2-minute window.
          if (message.canEdit && canReply)
            _ActionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () => Navigator.of(context).pop(MessageAction.edit),
            ),
          // Author-only, inside the 24-hour window. Still offered on a
          // blocked thread: removing your own words isn't a send.
          if (message.canDelete)
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: () => Navigator.of(context).pop(MessageAction.delete),
            ),
          SizedBox(height: Screen.getVerticalSize(8)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: Screen.getPadding(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: Screen.getSize(20), color: color),
            SizedBox(width: Screen.getHorizontalSize(16)),
            Text(
              label,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: color,
                fontSize: Screen.getFontSize(15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
