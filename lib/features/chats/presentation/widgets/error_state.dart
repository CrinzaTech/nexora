import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Failed-load state with a retry button. Surfaces the cubit's error
/// message verbatim — the cubit is responsible for keeping that copy
/// user-facing.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(16)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                "Retry",
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
