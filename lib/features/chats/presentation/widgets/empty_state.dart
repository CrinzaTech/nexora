import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// Shown when the backend returns no chat groups at all (user hasn't
/// enrolled in any paid course yet).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 80,
              color: AppColors.grey300,
            ),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              "No chat groups yet",
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              "Enroll in a course to join its chat group.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
