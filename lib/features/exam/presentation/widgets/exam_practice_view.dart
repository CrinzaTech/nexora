import 'package:flutter/material.dart';

import 'package:nexora/core/widgets/draggable_fab.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_input.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_palette.dart';

/// Practice drill: one question at a time, checked on the spot, with the
/// right answer shown whether the pick was right or wrong.
///
/// Nothing is recorded, so there is nothing to submit, no timer, no points
/// and no ranking — pick, see the answer, move on.
class ExamPracticeView extends StatefulWidget {
  final PracticeItem item;
  final int number;
  final int total;
  final ExamAnswerDraft draft;
  final PracticeAnswerResultResponse? verdict;
  final bool checking;
  final String? error;

  final ValueChanged<ExamAnswerDraft> onAnswerChanged;
  final VoidCallback onCheck;

  /// Next question — or skip, when nothing has been checked yet.
  final VoidCallback onNext;

  /// Back one question. Hidden on the first.
  final VoidCallback onPrevious;

  /// Straight to a question (0-based) from the review grid.
  final ValueChanged<int> onJumpTo;

  /// 0-based index → checked correct; only checked questions appear.
  final Map<int, bool> outcomes;

  /// 0-based indexes the student has been on.
  final Set<int> visited;

  const ExamPracticeView({
    super.key,
    required this.item,
    required this.number,
    required this.total,
    required this.draft,
    required this.verdict,
    required this.checking,
    required this.error,
    required this.onAnswerChanged,
    required this.onCheck,
    required this.onNext,
    required this.onPrevious,
    required this.onJumpTo,
    this.outcomes = const {},
    this.visited = const {},
  });

  @override
  State<ExamPracticeView> createState() => _ExamPracticeViewState();
}

class _ExamPracticeViewState extends State<ExamPracticeView> {
  final _scroll = ScrollController();

  ExamQuestion get _question => widget.item.question;
  PracticeAnswerResultResponse? get _verdict => widget.verdict;
  bool get _isLast => widget.number >= widget.total;

  /// One-tap types are answered by the tap itself; the rest need Check.
  bool get _checksOnSelect =>
      _question.questionType == ExamQuestionType.multipleChoice ||
      _question.questionType == ExamQuestionType.trueFalse;

  bool get _hasAnswer =>
      widget.draft.toRequestJson(_question.id, _question.questionType) != null;

  @override
  void didUpdateWidget(ExamPracticeView old) {
    super.didUpdateWidget(old);
    // A new question starts at the top, not where the last one was left.
    if (old.number != widget.number && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    final error = widget.error;
    if (error != null && error != old.error) {
      // Deferred: the toast inserts into the overlay, and this is mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        CustomSnackbar.error(context, title: 'Could not check', message: error);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _handleDraft(ExamAnswerDraft next) {
    if (_verdict != null || widget.checking) return;
    widget.onAnswerChanged(next);
    if (_checksOnSelect) widget.onCheck();
  }

  @override
  Widget build(BuildContext context) {
    final passage = widget.item.passage;
    final instructions = (widget.item.sectionInstructions ?? '').trim();
    return Column(
      children: [
        _header(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _questionList(passage, instructions)),
              Positioned.fill(
                child: DraggableFab(
                  margin: const EdgeInsets.all(AppSizes.paddingM),
                  builder: (ctx, _) =>
                      ExamStatsFab(pinnedCount: 0, onTap: () => _openGrid(ctx)),
                ),
              ),
            ],
          ),
        ),
        _actionBar(context),
      ],
    );
  }

  Widget _questionList(ExamQuestion? passage, String instructions) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingM,
      ),
      children: [
        ExamSectionHeader(name: widget.item.sectionName),
        if (instructions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.paddingS),
            child: ExamInstructionCallout(
              instructions,
              label: 'Section instructions',
            ),
          ),
        if (passage != null && passage.questionText.trim().isNotEmpty) ...[
          _passageCard(passage),
          const SizedBox(height: AppSizes.paddingS),
        ],
        ExamDraftScope(
          resolver: (_) => widget.draft,
          child: AbsorbPointer(
            absorbing: _verdict != null || widget.checking,
            child: ExamQuestionInput(
              question: _question,
              number: widget.number,
              draft: widget.draft,
              onChanged: (_, d) => _handleDraft(d),
              quizFeedback: _verdict == null
                  ? null
                  : ExamQuizFeedback(
                      correctOptionId: _verdict!.correctOptionId,
                      wrongOptionIds:
                          !_verdict!.isCorrect && widget.draft.optionId != null
                          ? {widget.draft.optionId!}
                          : const {},
                    ),
            ),
          ),
        ),
        if (_verdict != null) ...[
          const SizedBox(height: AppSizes.paddingM),
          _verdictCard(_verdict!),
        ],
      ],
    );
  }

  /// The review grid: right, wrong, skipped, this one, and not yet seen.
  /// Every cell is tappable — practice is held locally, so any question
  /// can be opened, answered or looked back at.
  Future<void> _openGrid(BuildContext context) async {
    final current = widget.number - 1;
    final index = await showExamQuestionPalette(
      context,
      reviewMode: true,
      entries: [
        for (var i = 0; i < widget.total; i++)
          ExamPaletteEntry(number: i + 1, status: _statusOf(i, current)),
      ],
    );
    if (index == null || !mounted || index == current) return;
    widget.onJumpTo(index);
  }

  ExamPaletteStatus _statusOf(int index, int current) {
    if (index == current) return ExamPaletteStatus.current;
    final outcome = widget.outcomes[index];
    if (outcome != null) {
      return outcome ? ExamPaletteStatus.correct : ExamPaletteStatus.wrong;
    }
    return widget.visited.contains(index)
        ? ExamPaletteStatus.skipped
        : ExamPaletteStatus.upcoming;
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header() {
    final progress = widget.total == 0
        ? 0.0
        : (widget.number / widget.total).clamp(0.0, 1.0);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${widget.number} of ${widget.total}',
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              ExamChip(
                'Practice',
                color: AppColors.success,
                icon: Icons.school_outlined,
              ),
            ],
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

  /// The comprehension passage this question is about.
  Widget _passageCard(ExamQuestion passage) {
    return ExamCard(
      background: AppColors.grey50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Read the passage',
            style: AppTypography.bodyTextSmallSemiBold.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ExamHtmlText(
            passage.questionText,
            baseStyle: AppTypography.bodyTextMedium,
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  // ── Verdict ────────────────────────────────────────────────────────────

  Widget _verdictCard(PracticeAnswerResultResponse verdict) {
    final correct = verdict.isCorrect;
    final accent = correct ? AppColors.success : AppColors.error;
    final answerLine = correct ? null : _correctAnswerLine(verdict);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.successBackground
            : AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 22,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct' : 'Wrong',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: accent,
                ),
              ),
            ],
          ),
          if (answerLine != null) ...[
            const SizedBox(height: 6),
            Text(
              answerLine,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (verdict.hasSolution) ...[
            const SizedBox(height: AppSizes.paddingS),
            Text(
              'Explanation',
              style: AppTypography.bodyTextSmallSemiBold.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            ExamHtmlText(
              verdict.solutionText!,
              baseStyle: AppTypography.bodyTextSmallMedium,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  /// Where the right answer is when it isn't already painted on the
  /// options. A multiple-choice answer is highlighted in green above, so it
  /// needs no words; true/false has only one other option.
  String? _correctAnswerLine(PracticeAnswerResultResponse verdict) {
    switch (_question.questionType) {
      case ExamQuestionType.multipleChoice:
        return verdict.correctOptionId == null
            ? null
            : 'The correct answer is highlighted in green.';
      case ExamQuestionType.trueFalse:
        final picked = widget.draft.boolean;
        if (picked == null) return null;
        return 'Correct answer: ${picked ? 'False' : 'True'}';
      default:
        return verdict.hasSolution ? null : 'Not the right answer.';
    }
  }

  // ── Action bar ─────────────────────────────────────────────────────────

  Widget _actionBar(BuildContext context) {
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
      child: _actions(),
    );
  }

  Widget _actions() {
    if (_verdict != null) {
      return _withPrevious(
        _primaryButton(
          label: _isLast ? 'Finish' : 'Next',
          icon: _isLast ? Icons.check : Icons.arrow_forward,
          onPressed: widget.onNext,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_checksOnSelect)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _hint(
              widget.checking
                  ? 'Checking…'
                  : 'Pick an option to check it instantly.',
            ),
          )
        else ...[
          _primaryButton(
            label: 'Check answer',
            icon: Icons.fact_check_outlined,
            onPressed: _hasAnswer ? widget.onCheck : null,
          ),
          const SizedBox(height: 8),
        ],
        _withPrevious(
          _outlinedButton(
            label: _isLast ? 'Skip & finish' : 'Skip',
            icon: Icons.skip_next_rounded,
            onPressed: widget.onNext,
          ),
        ),
      ],
    );
  }

  /// Puts a Previous button beside [forward] — except on the first
  /// question, where there is nowhere to go back to.
  Widget _withPrevious(Widget forward) {
    if (widget.number <= 1) return forward;
    return Row(
      children: [
        Expanded(
          child: _outlinedButton(
            label: 'Previous',
            icon: Icons.arrow_back_rounded,
            onPressed: widget.onPrevious,
            iconFirst: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: forward),
      ],
    );
  }

  Widget _outlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool iconFirst = false,
  }) {
    final color = AppColors.mutedTextPrimary;
    final text = Text(
      label,
      maxLines: 1,
      style: AppTypography.bodyTextSmallSemiBold.copyWith(color: color),
    );
    final glyph = Icon(icon, size: 18, color: color);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.checking ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.dividerLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconFirst
                ? [glyph, const SizedBox(width: 6), text]
                : [text, const SizedBox(width: 6), glyph],
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.checking) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyTextSmallMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.checking ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
        child: widget.checking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.alwaysWhite,
                  ),
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
                  Icon(icon, size: 20, color: AppColors.alwaysWhite),
                ],
              ),
      ),
    );
  }
}

/// End of a practice run: the client's own tally. Nothing was recorded.
class ExamPracticeSummaryView extends StatelessWidget {
  final int correct;
  final int answered;
  final int total;
  final VoidCallback onPracticeAgain;
  final VoidCallback onDone;

  const ExamPracticeSummaryView({
    super.key,
    required this.correct,
    required this.answered,
    required this.total,
    required this.onPracticeAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final skipped = total - answered;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 36,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Practice complete',
              style: AppTypography.h3SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$correct of $total correct',
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (skipped > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$skipped skipped',
                style: AppTypography.bodyTextSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.paddingXL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPracticeAgain,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Practice again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.alwaysWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDone,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.dividerLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                ),
                child: Text(
                  'Done',
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
