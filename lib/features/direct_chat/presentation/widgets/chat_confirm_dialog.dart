import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Confirmation dialog for the two destructive-looking chat actions.
///
/// They are **not** the same operation and the copy is the only thing
/// telling the learner which one they picked, so both messages are
/// pinned here as named constructors rather than passed in ad hoc:
///
///   - [deleteMessage] removes one message for **both sides**, forever.
///   - [clearHistory] hides the whole thread from **this learner only**;
///     the educator keeps everything and the server can undo it.
///
/// Wording mirrors the admin panel so a learner and a staff member
/// reading over each other's shoulder see the same promise.
class ChatConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;

  const ChatConfirmDialog._({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  /// Deleting one of the learner's own messages. Returns true on
  /// confirm, null/false otherwise.
  static Future<bool?> deleteMessage(
    BuildContext context, {
    required String otherUserName,
  }) {
    return _show(
      context,
      ChatConfirmDialog._(
        title: 'Delete this message?',
        body:
            'It will be removed for ${otherUserName.trim().isEmpty ? 'the educator' : otherUserName} '
            'as well. This cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
  }

  /// Clearing the learner's own view of the thread.
  static Future<bool?> clearHistory(
    BuildContext context, {
    required String otherUserName,
  }) {
    final name = otherUserName.trim().isEmpty
        ? 'The educator'
        : otherUserName;
    return _show(
      context,
      ChatConfirmDialog._(
        title: 'Clear chat history?',
        body:
            'Messages will be hidden from your side only. $name will still '
            'see the full conversation.',
        confirmLabel: 'Clear',
      ),
    );
  }

  static Future<bool?> _show(BuildContext context, ChatConfirmDialog dialog) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: Screen.getPadding(horizontal: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: Screen.getPadding(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.h5SemiBold.copyWith(
                  fontSize: Screen.getFontSize(19),
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: Screen.getFontSize(13.5),
                  height: 1.45,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(24)),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context, false),
                      backgroundColor: AppColors.white,
                      textColor: AppColors.primary,
                      borderColor: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox(width: Screen.getHorizontalSize(12)),
                  Expanded(
                    child: _DialogButton(
                      label: confirmLabel,
                      onTap: () => Navigator.pop(context, true),
                      backgroundColor: AppColors.error,
                      textColor: AppColors.white,
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isDestructive;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDestructive ? null : backgroundColor,
            gradient: isDestructive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor,
                      backgroundColor.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(50),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
            boxShadow: isDestructive
                ? [
                    BoxShadow(
                      color: backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: textColor,
              fontSize: Screen.getFontSize(14),
            ),
          ),
        ),
      ),
    );
  }
}
