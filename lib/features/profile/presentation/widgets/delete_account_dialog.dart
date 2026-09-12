import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:nexora/features/profile/domain/usecases/delete_account_usecase.dart';

/// Confirmation gate in front of requesting account deletion.
///
/// Returns the learner's stated reason on confirm, or `null` if they
/// backed out. The reason is not optional decoration — the API rejects a
/// blank one with a 400 — so the confirm button stays inert until
/// something is typed. That doubles as the deliberateness check a
/// destructive action needs, which is why there is no separate
/// "type DELETE" step.
///
/// **The copy says "request" throughout, on purpose.** The backend files
/// a row for back-office processing and deletes nothing on the spot, so
/// promising the account is gone would be a lie the learner could
/// disprove by signing back in. What *is* immediate is being signed out,
/// and that is stated too.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog._();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      // No tap-outside dismissal: the field takes focus and raises the
      // keyboard, and a stray tap on the dimmed area behind it should
      // not read as an answer either way.
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog._(),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: Screen.getPadding(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: Screen.getPadding(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: Screen.getSize(44),
              ),
              SizedBox(height: Screen.getVerticalSize(14)),
              Text(
                'Delete your account?',
                textAlign: TextAlign.center,
                style: AppTypography.h5SemiBold.copyWith(
                  fontSize: Screen.getFontSizeCapped(20),
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(12)),
              Text(
                'This sends a deletion request to our team. It does '
                'not happen straight away.\n\n'
                'You will be signed out now. Once the request is '
                'processed, your courses, progress, certificates, '
                'bookings and chat history are removed for good.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextMedium.copyWith(
                  fontSize: Screen.getFontSizeCapped(13),
                  color: AppColors.textPrimary.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(20)),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Why are you leaving?',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    fontSize: Screen.getFontSizeCapped(12),
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(8)),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                // Capped to what the API's column will take. See
                // DeleteAccountUseCase.maxReasonLength — the use case
                // trims as well, so a paste can't slip past this.
                maxLength: DeleteAccountUseCase.maxReasonLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                onChanged: (_) => setState(() {}),
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSizeCapped(14),
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us in a few words…',
                  hintStyle: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary.withValues(alpha: 0.6),
                    fontSize: Screen.getFontSizeCapped(14),
                  ),
                  filled: true,
                  fillColor: AppColors.error.withValues(alpha: 0.04),
                  contentPadding: Screen.getPadding(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: _border(AppColors.error.withValues(alpha: 0.25)),
                  enabledBorder: _border(
                    AppColors.error.withValues(alpha: 0.25),
                  ),
                  focusedBorder: _border(AppColors.error),
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(22)),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      backgroundColor: AppColors.white,
                      textColor: AppColors.primary,
                      borderColor: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox(width: Screen.getHorizontalSize(12)),
                  Expanded(
                    child: _DialogButton(
                      label: 'Send request',
                      // Inert rather than absent until a reason is
                      // typed: a button that vanishes mid-dialog reads
                      // as a bug.
                      onTap: _confirmed
                          ? () =>
                                Navigator.pop(context, _controller.text.trim())
                          : null,
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

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

class _DialogButton extends StatelessWidget {
  final String label;

  /// `null` disables the button — it dims and stops taking taps.
  final VoidCallback? onTap;
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
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
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
              boxShadow: isDestructive && enabled
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
            padding: EdgeInsets.symmetric(
              horizontal: Screen.getHorizontalSize(8),
            ),
            // Clamped rather than left to wrap: the pill is a fixed 48pt
            // and a label that wraps to two lines spills straight out of
            // it. Ellipsis keeps that contained for any label or locale.
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: textColor,
                fontSize: Screen.getFontSize(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
