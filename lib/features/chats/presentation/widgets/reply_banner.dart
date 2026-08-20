import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Slim "Replying to X" strip that sits between the message list and
/// the composer when the user has staged a reply.
///
/// Takes the notifier and the cancel callback rather than a cubit so
/// group chat and personal chat can both drive it — their room cubits
/// are separate classes that happen to expose the same two members.
/// Watching a [ValueListenable] keeps the banner animating in and out
/// without rebuilding the message list behind it.
class ReplyBanner extends StatelessWidget {
  /// Usually a room cubit's `replyingTo`. Null means "no staged reply",
  /// which renders as nothing.
  final ValueListenable<ChatMessage?> replyingTo;

  /// Clears the staged reply — the dismiss "x" calls this.
  final VoidCallback onCancel;

  /// Overrides the "Replying to X" heading. The edit flow reuses this
  /// same strip for "Editing message", since the shape — quoted
  /// preview, accent bar, dismiss "x" — is identical and only the verb
  /// differs.
  final String Function(ChatMessage)? labelBuilder;

  const ReplyBanner({
    super.key,
    required this.replyingTo,
    required this.onCancel,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatMessage?>(
      valueListenable: replyingTo,
      builder: (_, message, __) {
        // AnimatedSwitcher gives the banner a soft fade+slide-in when a
        // reply is staged and a fade-out on cancel/send.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            return SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: message == null
              ? const SizedBox.shrink(key: ValueKey('reply-empty'))
              : _BannerBody(
                  key: ValueKey('reply-${message.id}'),
                  message: message,
                  onCancel: onCancel,
                  label: labelBuilder?.call(message),
                ),
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;

  /// Null falls back to the reply wording.
  final String? label;

  const _BannerBody({
    super.key,
    required this.message,
    required this.onCancel,
    this.label,
  });

  /// Short label for the previewed message — for non-text payloads we
  /// fall back to the media kind so the strip never goes empty.
  String get _preview {
    if (message.message.trim().isNotEmpty) return message.message.trim();
    switch (message.messageType) {
      case ChatMessageType.image:
        return '📷 Photo';
      case ChatMessageType.file:
        return '📎 Attachment';
      case ChatMessageType.audio:
        return '🎤 Voice message';
      case ChatMessageType.text:
        return '';
    }
  }

  String get _senderLabel {
    final override = label;
    if (override != null && override.isNotEmpty) return override;
    if (message.isFromCurrentStudent) return 'Replying to yourself';
    final name = message.senderName.trim();
    return name.isEmpty ? 'Replying' : 'Replying to $name';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(14),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(10),
        vertical: Screen.getVerticalSize(8),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Screen.getSize(12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Vertical primary bar — same affordance WhatsApp uses to
          // distinguish a quoted block from regular text.
          Container(
            width: Screen.getHorizontalSize(3),
            height: Screen.getVerticalSize(36),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _senderLabel,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(2)),
                Text(
                  _preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontSize: Screen.getFontSize(13),
                  ),
                ),
              ],
            ),
          ),
          // Dismiss "x" — clears the staged reply without sending.
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.mutedTextPrimary,
              size: Screen.getSize(18),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
