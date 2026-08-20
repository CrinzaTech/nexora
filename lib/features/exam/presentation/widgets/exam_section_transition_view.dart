import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';

/// Between-sections screen shown in competitive mode after the last
/// question of a section is answered. The student reads the next section's
/// context, then taps Continue — there is no going back to the previous
/// section.
class ExamSectionTransitionView extends StatelessWidget {
  final String? fromSectionName;
  final String nextSectionName;
  final bool loading;
  final VoidCallback onContinue;

  const ExamSectionTransitionView({
    super.key,
    required this.fromSectionName,
    required this.nextSectionName,
    required this.loading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.dividerLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Green success band.
            Container(
              width: double.infinity,
              color: AppColors.success.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.paddingXL,
                horizontal: AppSizes.paddingL,
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 34, color: AppColors.success),
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    'SECTION COMPLETE',
                    style: AppTypography.bodyTextSmallSemiBold.copyWith(
                      color: AppColors.success,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fromSectionName != null && fromSectionName!.isNotEmpty
                        ? 'You have finished $fromSectionName'
                        : 'You have finished this section',
                    style: AppTypography.h3Bold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nice work. Here is what comes next.',
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                children: [
                  // "Now starting" box.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'NOW STARTING',
                          style: AppTypography.bodyTextSmallSemiBold.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextSectionName,
                          style: AppTypography.h3Bold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  // Info banner.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The next section may have its own instructions. '
                            'Please read them carefully before answering its '
                            'first question. You will not be able to return to '
                            '${fromSectionName ?? 'the previous section'} once you continue.',
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusCircle),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppColors.alwaysWhite),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Continue',
                                  style: AppTypography.bodyTextLargeSemiBold
                                      .copyWith(color: AppColors.alwaysWhite),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward,
                                    size: 20, color: AppColors.alwaysWhite),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
