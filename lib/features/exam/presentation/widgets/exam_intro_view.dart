import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';

/// Intro / gate screen. Shows exam meta, instructions, an optional
/// last-score banner, and the correct CTA for the gate state.
class ExamIntroView extends StatelessWidget {
  final AttemptStateResponse gate;
  final VoidCallback onStart;
  final VoidCallback onReattempt;
  final void Function(int attemptId) onViewResult;
  final VoidCallback onOpenHistory;

  const ExamIntroView({
    super.key,
    required this.gate,
    required this.onStart,
    required this.onReattempt,
    required this.onViewResult,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(),
          if (gate.isCompetitive) ...[
            const SizedBox(height: AppSizes.paddingM),
            _competitiveNotice(),
          ],
          if (gate.hasLastEvaluated) ...[
            const SizedBox(height: AppSizes.paddingM),
            _lastScoreBanner(),
          ],
          if (gate.hasInstructions &&
              (gate.instructions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingM),
            _instructionsCard(),
          ],
          const SizedBox(height: AppSizes.paddingL),
          _cta(),
          if (gate.attemptsUsed > 0) ...[
            const SizedBox(height: AppSizes.paddingS),
            Center(
              child: TextButton.icon(
                onPressed: onOpenHistory,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View attempt history'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCard() {
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gate.examTitle,
            style: AppTypography.h3Bold.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (gate.durationMinutes != null)
                ExamChip(
                  '${gate.durationMinutes} min',
                  color: AppColors.info,
                  icon: Icons.timer_outlined,
                ),
              ExamChip(
                gate.isCompetitive ? 'Competitive mode' : 'Normal mode',
                color:
                    gate.isCompetitive ? AppColors.warning : AppColors.success,
                icon: gate.isCompetitive
                    ? Icons.bolt_outlined
                    : Icons.assignment_outlined,
              ),
              // Said here, before the clock starts, so nobody discovers
              // mid-paper that they didn't need to do it by hand.
              if (gate.allowCalculator)
                ExamChip(
                  gate.calculatorType == ExamCalculatorType.scientific
                      ? 'Scientific calculator'
                      : 'Calculator provided',
                  color: AppColors.primary,
                  icon: Icons.calculate_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _competitiveNotice() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This exam shows one question at a time. Once you continue to the '
              "next question you can't go back, and each question is timed.",
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.warningDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionsCard() {
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Instructions',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingS),
          ExamHtmlText(
            gate.instructions!,
            baseStyle: AppTypography.bodyTextMedium,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _lastScoreBanner() {
    final score = gate.lastEvaluatedScore;
    final max = gate.lastEvaluatedMaxScore;
    final passed = gate.lastEvaluatedIsPassed;
    final Color tint = passed == false ? AppColors.error : AppColors.success;
    return InkWell(
      onTap: gate.lastEvaluatedAttemptId != null
          ? () => onViewResult(gate.lastEvaluatedAttemptId!)
          : null,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: tint.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              passed == false ? Icons.replay_circle_filled : Icons.emoji_events,
              color: tint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your last attempt',
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    score != null && max != null
                        ? 'Scored ${formatMarks(score)} / ${formatMarks(max)}'
                        : 'View your result',
                    style: AppTypography.bodyTextLargeSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tint),
          ],
        ),
      ),
    );
  }

  Widget _cta() {
    // Gate not open → informational message, plus last-result access.
    if (!gate.isOpen) {
      return _closedState();
    }

    final bool resume = gate.hasInProgressAttempt;
    final bool reattempt = !resume && gate.attemptsUsed > 0;
    final String label = resume
        ? 'Resume Exam'
        : reattempt
            ? 'Reattempt Exam'
            : 'Start Exam';

    // Attempts fully used and none in progress → no CTA, just last result.
    if (reattempt && !gate.canReattempt) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Text(
              "You've used all ${gate.maxAttempts} attempt(s) for this exam.",
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.warningDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return CustomActionButton(
      name: label,
      isFormFilled: true,
      onTap: (start, stop, state) {
        if (resume || !reattempt) {
          onStart();
        } else {
          onReattempt();
        }
      },
    );
  }

  Widget _closedState() {
    late final String message;
    late final IconData icon;
    switch (gate.gateState) {
      case ExamGateState.notStarted:
        icon = Icons.schedule;
        message = "This exam hasn't started yet. Please check back later.";
      case ExamGateState.ended:
        icon = Icons.event_busy;
        message = 'This exam has ended.';
      case ExamGateState.notPublished:
        icon = Icons.lock_outline;
        message = 'This exam is not available yet.';
      case ExamGateState.notFound:
        icon = Icons.help_outline;
        message = 'This exam could not be found.';
      case ExamGateState.open:
      case ExamGateState.unknown:
        icon = Icons.info_outline;
        message = 'This exam is not available right now.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.dividerLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.mutedTextPrimary),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            message,
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
