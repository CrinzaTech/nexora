import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Email input replacement used everywhere the app collects an email
/// from a device Google account instead of free text — kills the
/// typo-in-email failure mode a keyboard invites.
///
/// Shows a "Continue with Google" button when [email] is empty, or a
/// green "picked" pill with [email] and a "Change" affordance once one
/// has been selected. [onPick] opens the native account picker; the
/// caller is responsible for writing the result back into whatever
/// backs [email].
class GoogleEmailPickerField extends StatelessWidget {
  const GoogleEmailPickerField({
    super.key,
    required this.email,
    required this.isLoading,
    required this.onPick,
  });

  final String email;
  final bool isLoading;
  final Future<void> Function() onPick;

  bool get _hasEmail => email.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _hasEmail
        ? _SelectedEmailPreview(
            email: email.trim(),
            onChangeTap: isLoading ? null : onPick,
          )
        : _GoogleEmailPickerButton(isLoading: isLoading, onTap: onPick);
  }
}

class _GoogleEmailPickerButton extends StatelessWidget {
  const _GoogleEmailPickerButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Screen.getVerticalSize(52),
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => onTap(),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.grey200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: Screen.getSize(22),
                  height: Screen.getSize(22),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: Screen.getFontSizeCapped(14),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4285F4),
                    ),
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(10)),
                Text(
                  'Continue with Google',
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: Colors.black87,
                    fontSize: Screen.getFontSizeCapped(15),
                    letterSpacing: -0.01,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown once a Google account has been picked — a "selected" pill with
/// a green check so the user gets clear confirmation. Tapping it
/// re-opens the picker to switch accounts.
class _SelectedEmailPreview extends StatelessWidget {
  const _SelectedEmailPreview({required this.email, required this.onChangeTap});

  final String email;
  final VoidCallback? onChangeTap;

  static const _successColor = Color(0xFF39B72D);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Screen.getVerticalSize(52),
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChangeTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Screen.getHorizontalSize(16),
            ),
            decoration: BoxDecoration(
              color: _successColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: _successColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: _successColor,
                  size: Screen.getSize(22),
                ),
                SizedBox(width: Screen.getHorizontalSize(10)),
                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextLargeSemiBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: Screen.getFontSizeCapped(14),
                      letterSpacing: -0.01,
                    ),
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(8)),
                Text(
                  'Change',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                    fontSize: Screen.getFontSizeCapped(12),
                    letterSpacing: -0.01,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
