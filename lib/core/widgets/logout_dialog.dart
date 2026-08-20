import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog._();

  /// Show the logout confirmation dialog.
  /// Returns `true` if the user confirms, `null`/`false` otherwise.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LogoutDialog._(),
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
                'Are you sure you want\nto logout ?',
                textAlign: TextAlign.center,
                style: AppTypography.h5SemiBold.copyWith(
                  fontSize: Screen.getFontSize(20),
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(24)),
              Row(
                children: [
                  // Cancel button
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
                  // Yes, Logout button
                  Expanded(
                    child: _DialogButton(
                      label: 'Yes, Logout',
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
