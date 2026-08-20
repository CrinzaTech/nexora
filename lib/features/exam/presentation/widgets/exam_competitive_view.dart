import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_input.dart';

/// Competitive mode: one question at a time. The student answers and taps
/// Save & Next — there is no going back. Time spent on the question is
/// measured server-side (from the `shown_at` stamp set when this question
/// was fetched), so it can't be tampered with from the client.
class ExamCompetitiveView extends StatelessWidget {
  final CompetitiveQuestionResponse data;
  final ExamAnswerDraft draft;
  final bool submitting;
  final ValueChanged<ExamAnswerDraft> onAnswerChanged;
  final VoidCallback onSaveNext;

  const ExamCompetitiveView({
    super.key,
    required this.data,
    required this.draft,
    required this.submitting,
    required this.onAnswerChanged,
    required this.onSaveNext,
  });

  @override
  Widget build(BuildContext context) {
    final question = data.question;
    final progress = data.totalQuestions == 0
        ? 0.0
        : (data.questionNumber / data.totalQuestions).clamp(0.0, 1.0);

    return Column(
      children: [
        _header(progress),
        Expanded(
          child: question == null
              ? const SizedBox.shrink()
              : ExamDraftScope(
                  // One live draft for the current question (and any
                  // comprehension children resolve to it too).
                  resolver: (_) => draft,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.paddingS,
                      AppSizes.paddingM,
                      AppSizes.paddingM,
                    ),
                    children: [
                      ExamSectionHeader(name: data.sectionName ?? 'Section'),
                      if ((data.sectionInstructions ?? '').trim().isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSizes.paddingS),
                          child: ExamInstructionCallout(
                            data.sectionInstructions!,
                            label: 'Section instructions',
                          ),
                        ),
                      _noReturnBanner(),
                      const SizedBox(height: AppSizes.paddingS),
                      ExamQuestionInput(
                        question: question,
                        number: data.questionNumber,
                        draft: draft,
                        onChanged: (_, d) => onAnswerChanged(d),
                      ),
                    ],
                  ),
                ),
        ),
        _saveBar(context),
      ],
    );
  }

  Widget _header(double progress) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.examTitle,
            style: AppTypography.h3Bold.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Question ${data.questionNumber} of ${data.totalQuestions}',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.grey100,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noReturnBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You will not be able to come back to this question once you continue.',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.warningDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final label = data.isLast ? 'Save & Finish' : 'Save & Next';
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingS + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          // No confirmation in competitive mode — a single tap saves the
          // answer and advances (there is no going back regardless).
          onPressed: submitting ? null : onSaveNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.alwaysWhite),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      data.isLast ? Icons.check : Icons.arrow_forward,
                      size: 20,
                      color: AppColors.alwaysWhite,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
