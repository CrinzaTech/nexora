import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';

/// The right/wrong/shown verdict for one quiz question, with the worked
/// explanation underneath when the question has one.
///
/// Shared by the live quiz screen and the look-back sheet so a question
/// reads identically whether the student is seeing the verdict for the
/// first time or reopening it from the progress grid.
class ExamQuizVerdictCard extends StatelessWidget {
  final QuizAnswerResultResponse result;

  /// The attempt's full points budget, for the "x of y points used" chip.
  final int retryPoints;

  /// The student skipped past without answering. It settles like a wrong
  /// answer server-side, but calling it wrong would be untrue and would
  /// tell them off for something they never did.
  final bool unattempted;

  const ExamQuizVerdictCard({
    super.key,
    required this.result,
    required this.retryPoints,
    this.unattempted = false,
  });

  @override
  Widget build(BuildContext context) => _card();

  Widget _card() {
    // A reveal is neither "right" nor "wrong" — the student paid to be
    // shown it. Saying "Wrong answer" there would be both untrue and
    // needlessly discouraging, so it gets its own voice.
    final revealed = result.answerRevealed;
    final correct = result.isCorrect;
    final accent = unattempted
        ? AppColors.mutedTextPrimary
        : revealed
        ? AppColors.info
        : (correct ? AppColors.success : AppColors.error);
    final title = unattempted
        ? 'Not answered'
        : revealed
        ? 'Answer shown'
        : (correct
              ? 'Correct'
              : (result.canRetry ? 'Not quite' : 'Wrong answer'));

    final String message;
    if (unattempted) {
      message =
          'You skipped this one. Answering it from the progress grid is '
          'still your first try, so it costs nothing.';
    } else if (revealed) {
      message =
          'You spent ${QuizPointCosts.reveal} points to see this, and the '
          'question earns its marks. Points never cost marks, they count '
          'against your ranking. The correct answer is highlighted above.';
    } else {
      message = switch ((correct, result.canRetry)) {
        (true, _) =>
          result.pointsSpent
              ? 'That is the right answer. Your marks are unaffected by the '
                    'retry. It only counts towards your ranking.'
              : 'That is the right answer.',
        (false, true) =>
          'Spend ${QuizPointCosts.retry} point to change your answer, or '
              'keep this one and move on. Keeping it is free.',
        // Deliberately does NOT show the answer. Settling wrong is free
        // (moveOn) or forced (out of points); handing the answer over
        // there would make a hint pointless — see
        // QuizAnswerResultResponse.disclosesAnswer.
        (false, false) =>
          'You can come back to this from the progress grid and try again '
              'for ${QuizPointCosts.retry} point.',
      };
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: unattempted
            ? AppColors.grey50
            : revealed
            ? AppColors.infoBackground
            : (correct
                  ? AppColors.successBackground
                  : AppColors.errorBackground),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unattempted
                ? Icons.remove_circle_outline_rounded
                : revealed
                ? Icons.lightbulb_outline_rounded
                : (correct ? Icons.check_circle_rounded : Icons.cancel_rounded),
            size: 22,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (result.pointsSpent) ...[
                  const SizedBox(height: AppSizes.paddingS),
                  ExamChip(
                    '${result.retryPointsUsed} of $retryPoints points used',
                    color: AppColors.warning,
                    icon: Icons.toll_outlined,
                  ),
                ],
                // The teaching moment. Only ever present once the question
                // is settled — the API withholds it while a retry is still
                // on the table, so it can't hand over the answer early.
                if (result.hasSolution) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  _explanationPanel(result.shownSolutionText!, accent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The question's worked explanation. Sits inside the verdict card on its
  /// own surface so it reads as reference material rather than more of the
  /// verdict sentence.
  Widget _explanationPanel(String html, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 14,
                color: AppColors.infoDark,
              ),
              const SizedBox(width: 5),
              Text(
                'Explanation',
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.infoDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ExamHtmlText(
            html,
            baseStyle: AppTypography.bodyTextSmallMedium,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
