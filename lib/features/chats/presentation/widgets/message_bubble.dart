import 'dart:math' as math;

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Surface for an *incoming* bubble.
///
/// In light mode a white bubble already separates from the cream chat
/// page. In dark mode `AppColors.white` and the chat page both resolve
/// to the same surface tone, so an incoming bubble would disappear into
/// the background — it has to step up to the elevated surface instead.
Color get _incomingBubble =>
    AppColors.isDark ? AppColors.grey100 : AppColors.white;

/// Hairline that gives an incoming bubble an edge on a dark canvas,
/// where the 1px black shadow it relies on in light mode is invisible.
BoxBorder? get _incomingBubbleBorder => AppColors.isDark
    ? Border.all(color: AppColors.alwaysWhite.withValues(alpha: 0.07))
    : null;

/// Single chat-message bubble. Layout flips based on
/// [ChatMessage.isFromCurrentStudent]:
///   - right-aligned, primary-tinted fill for the user
///   - left-aligned, white fill + soft shadow + sender label for others
///
/// Special-case rendering for non-text payloads:
///   - image messages render as a stand-alone framed tile (purple
///     border for "me", white card for others) so the photo can fill
///     the bubble width edge-to-edge instead of being padded inside
///     the regular text-bubble container.
///   - file / audio messages render as a richer tile with a filename
///     + type/size subtitle + trailing time, anchored on the side the
///     sender belongs to (right for me, left for others).
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// True when this bubble belongs to the same sender as the bubble
  /// directly above (in chronological reading order). Drives sender-
  /// name suppression so consecutive messages don't repeat the label.
  final bool sameSenderAsPrev;

  const MessageBubble({
    super.key,
    required this.message,
    this.sameSenderAsPrev = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromCurrentStudent;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final crossAxis = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Align(
      alignment: align,
      // `mainAxisSize: min` + the ConstrainedBox give us the WhatsApp
      // sizing rule: the bubble caps at 78% of screen width when the
      // text is long, but hugs the content's intrinsic width when the
      // message is short — so a one-word reply doesn't stretch into a
      // long horizontal slab.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(Screen.width * 0.78, 480),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxis,
          children: [
            if (!isMe && !sameSenderAsPrev && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.senderName,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
              ),
            _bubbleForType(isMe: isMe),
          ],
        ),
      ),
    );
  }

  /// Per-type renderer. Text routes through [_TextBubble] (the regular
  /// rounded fill), image through [_ImageBubble] (framed tile),
  /// file/audio through [_FileTile] (rich attachment row).
  Widget _bubbleForType({required bool isMe}) {
    switch (message.messageType) {
      case ChatMessageType.image:
        return _ImageBubble(message: message, isMe: isMe);
      case ChatMessageType.file:
      case ChatMessageType.audio:
        return _FileTile(message: message, isMe: isMe);
      case ChatMessageType.text:
        return _TextBubble(
          message: message,
          isMe: isMe,
          sameSenderAsPrev: sameSenderAsPrev,
        );
    }
  }
}

/// Formatted send time in the bubble's lower-right ("2:47 PM"), with an
/// "edited" marker in front of it when the author rewrote the message.
/// Pulled out so every bubble variant shares the same styling rule.
class _BubbleTimestamp extends StatelessWidget {
  final DateTime time;
  final Color color;

  /// Renders "edited · 2:47 PM". Deliberately the same muted colour and
  /// size as the timestamp — it's a footnote, not a badge.
  final bool isEdited;

  const _BubbleTimestamp({
    required this.time,
    required this.color,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    final stamp = DateFormat('h:mm a').format(time);
    return Text(
      isEdited ? 'edited · $stamp' : stamp,
      style: AppTypography.bodyTextMedium.copyWith(
        color: color,
        fontSize: Screen.getFontSize(10),
      ),
    );
  }
}

/// Regular text bubble. Right-aligned + primary-fill for "me",
/// left-aligned + white-with-soft-shadow for everyone else.
class _TextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  /// True when this bubble belongs to the same sender as the bubble
  /// directly above it. Drives the "tail" corner: only the first
  /// bubble of a sender-run gets the clipped corner; follow-ups get
  /// all-rounded corners so the run reads as one unit.
  final bool sameSenderAsPrev;

  const _TextBubble({
    required this.message,
    required this.isMe,
    required this.sameSenderAsPrev,
  });

  @override
  Widget build(BuildContext context) {
    // WhatsApp-style bubble shape — small 10 px corners across the
    // bubble, with the bubble's "tail" corner clipped to 3 px so it
    // visually points at the sender. The tail only appears on the
    // first bubble of a sender-run; consecutive bubbles from the same
    // sender get all-rounded corners so the run reads as one unit.
    // alwaysWhite, not white: the bubble fill is AppColors.primary in
    // both themes, so its content must not follow the surface token —
    // that's what rendered the message text dark-on-indigo.
    final textColor = isMe ? AppColors.alwaysWhite : AppColors.textPrimary;
    final timeColor = isMe
        ? AppColors.alwaysWhite.withValues(alpha: 0.85)
        : AppColors.mutedTextPrimary;
    final radius = Screen.getSize(10);
    final tailRadius = Screen.getSize(3);
    final showTail = !sameSenderAsPrev;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && showTail ? tailRadius : radius),
      topRight: Radius.circular(isMe && showTail ? tailRadius : radius),
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(9),
        vertical: Screen.getVerticalSize(6),
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : _incomingBubble,
        border: isMe ? null : _incomingBubbleBorder,
        borderRadius: borderRadius,
        // WhatsApp's bubbles sit on a tiny 1 px shadow — just enough to
        // separate them from the surface without looking like cards.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // `IntrinsicWidth` lets the bubble hug the content's natural
      // width (so a "hi" reply doesn't stretch to the cap), while the
      // outer ConstrainedBox still caps long messages at 0.78 ×
      // screenWidth.
      child: IntrinsicWidth(
        child: Stack(
          children: [
            // Reserve a corner at the bottom-right of the text block for
            // the timestamp to slide into. The 56 px reserve is sized
            // to fit "12:45 AM" comfortably — an edited message prefixes
            // "edited · " and needs roughly 40 px more, or the last line
            // of text runs under it. The 14 px bottom reserve gives the
            // timestamp a baseline below the last line of text,
            // matching WhatsApp's inline placement.
            Padding(
              padding: EdgeInsets.only(
                right: Screen.getHorizontalSize(message.isEdited ? 96 : 56),
                bottom: Screen.getVerticalSize(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    _ReplyPreview(replyTo: message.replyTo!, tintLight: isMe),
                  Text(
                    message.message,
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: textColor,
                      fontSize: Screen.getFontSize(14.5),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _BubbleTimestamp(
                time: message.createdAt,
                color: timeColor,
                isEdited: message.isEdited,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo attachment — framed tile that hosts the image edge-to-edge
/// with a thin purple border for "me" and a plain white card for
/// others. The timestamp sits inside the frame at the bottom-right,
/// matching the design's "image with time inside the purple frame".
class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ImageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final radius = AppSizes.radiusL.toDouble();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _incomingBubble,
        borderRadius: BorderRadius.circular(radius),
        // Outgoing image bubbles get a heavy primary border so they
        // read as "yours" even without a fill — the photo itself is
        // the visual centre, so we keep the chrome thin.
        border: isMe ? Border.all(color: AppColors.primary, width: 3) : null,
        boxShadow: isMe
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius - 6),
            child: SizedBox(
              width: math.min(Screen.width * 0.55, 340),
              child: CustomNetworkImage(
                url: message.mediaUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: AppColors.grey200,
                  height: 140,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.grey400,
                  ),
                ),
              ),
            ),
          ),
          if (message.message.isNotEmpty) ...[
            SizedBox(height: Screen.getVerticalSize(6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                message.message,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSize(14),
                  height: 1.35,
                ),
              ),
            ),
          ],
          SizedBox(height: Screen.getVerticalSize(6)),
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            child: Align(
              alignment: Alignment.bottomRight,
              child: _BubbleTimestamp(
                time: message.createdAt,
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// File / audio attachment tile. Bigger surface than the legacy chip
/// — leading icon block, filename + "TYPE · SIZE" subtitle, trailing
/// time. The filename is derived from `mediaUrl`'s last path segment;
/// the size hint comes from the wire if the backend ships it on the
/// message ([ChatMessage.mediaSizeBytes]).
class _FileTile extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _FileTile({required this.message, required this.isMe});

  String get _filename {
    final url = message.mediaUrl;
    if (url != null && url.isNotEmpty) {
      final seg = Uri.tryParse(url)?.pathSegments.lastOrNull;
      if (seg != null && seg.isNotEmpty) return seg;
    }
    if (message.messageType == ChatMessageType.audio) return 'audio';
    return 'attachment';
  }

  String get _extensionLabel {
    final dot = _filename.lastIndexOf('.');
    if (dot <= 0 || dot == _filename.length - 1) {
      return message.messageType == ChatMessageType.audio ? 'AUDIO' : 'FILE';
    }
    return _filename.substring(dot + 1).toUpperCase();
  }

  Color get _accent {
    // PDFs get the conventional red glyph; everything else falls back
    // to the app primary so the tile reads as a single cohesive family.
    return _extensionLabel == 'PDF'
        ? const Color(0xFFE53935)
        : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final radius = AppSizes.radiusL.toDouble();
    return Container(
      width: math.min(Screen.width * 0.72, 420),
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : _incomingBubble,
        border: isMe ? null : _incomingBubbleBorder,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: isMe
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Screen.getSize(44),
                height: Screen.getSize(44),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.alwaysWhite.withValues(alpha: 0.15)
                      : _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                alignment: Alignment.center,
                child: Text(
                  _extensionLabel,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: isMe ? AppColors.alwaysWhite : _accent,
                    fontWeight: FontWeight.w800,
                    fontSize: Screen.getFontSize(10),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.message.isNotEmpty ? message.message : _filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: isMe ? AppColors.alwaysWhite : AppColors.textPrimary,
                        fontSize: Screen.getFontSize(14),
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(2)),
                    Text(
                      _extensionLabel,
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: isMe
                            ? AppColors.alwaysWhite.withValues(alpha: 0.85)
                            : AppColors.mutedTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: Screen.getFontSize(12),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(8)),
          Align(
            alignment: Alignment.bottomRight,
            child: _BubbleTimestamp(
              time: message.createdAt,
              color: isMe
                  ? AppColors.alwaysWhite.withValues(alpha: 0.7)
                  : AppColors.mutedTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessage replyTo;
  final bool tintLight;

  const _ReplyPreview({required this.replyTo, required this.tintLight});

  @override
  Widget build(BuildContext context) {
    final tint = tintLight
        ? AppColors.alwaysWhite.withValues(alpha: 0.25)
        : AppColors.primary.withValues(alpha: 0.12);
    final fg = tintLight
        ? AppColors.alwaysWhite.withValues(alpha: 0.9)
        : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: Screen.getPadding(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border(left: BorderSide(color: fg, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo.senderName.isNotEmpty)
            Text(
              replyTo.senderName,
              style: AppTypography.bodyTextMedium.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: Screen.getFontSize(11),
              ),
            ),
          Text(
            replyTo.messageType == ChatMessageType.text
                ? replyTo.message
                : replyTo.messageType == ChatMessageType.image
                ? '📷 Image'
                : '📎 Attachment',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextMedium.copyWith(
              color: fg,
              fontSize: Screen.getFontSize(12),
            ),
          ),
        ],
      ),
    );
  }
}
