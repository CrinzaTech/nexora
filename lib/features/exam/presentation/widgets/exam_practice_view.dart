import 'package:flutter/material.dart';

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

  /// Swipe left: next question — or skip, when nothing has been checked
  /// yet. Past the last question it finishes the run.
  final VoidCallback onNext;

  /// Swipe right: back one question. Ignored on the first.
  final VoidCallback onPrevious;

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
    this.visited = const {},
  });

  @override
  State<ExamPracticeView> createState() => _ExamPracticeViewState();
}

class _ExamPracticeViewState extends State<ExamPracticeView>
    with SingleTickerProviderStateMixin {
  // ── Swipe navigation ───────────────────────────────────────────────────
  //
  // No Previous / Skip / Next buttons: the student swipes. Swiping left
  // goes forward (an unanswered question counts as skipped, exactly as
  // the Skip button did), swiping right goes back. The question follows
  // the finger, and a short or slow swipe springs back.

  /// How far the current question has been dragged sideways.
  double _dragDx = 0;

  /// Direction of the last move, so the next question slides in from the
  /// side the student swiped towards.
  bool _forward = true;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(_onSnapTick);
  double _snapFrom = 0;

  /// A swipe this fast moves on, however short it was.
  static const double _flingVelocity = 400;

  /// Or one this long (as a fraction of the width), however slow.
  static const double _swipeFraction = 0.22;

  ExamQuestion get _question => widget.item.question;
  PracticeAnswerResultResponse? get _verdict => widget.verdict;
  bool get _isLast => widget.number >= widget.total;
  bool get _isFirst => widget.number <= 1;

  /// One-tap types are answered by the tap itself; the rest need Check.
  bool get _checksOnSelect =>
      _question.questionType == ExamQuestionType.multipleChoice ||
      _question.questionType == ExamQuestionType.trueFalse;

  bool get _hasAnswer =>
      widget.draft.toRequestJson(_question.id, _question.questionType) != null;

  @override
  void didUpdateWidget(ExamPracticeView old) {
    super.didUpdateWidget(old);
    if (old.number != widget.number) {
      // Covers swipes and grid jumps alike.
      _forward = widget.number > old.number;
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
    _snap.dispose();
    super.dispose();
  }

  void _handleDraft(ExamAnswerDraft next) {
    if (_verdict != null || widget.checking) return;
    widget.onAnswerChanged(next);
    if (_checksOnSelect) widget.onCheck();
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_snap.isAnimating) _snap.stop();
    var dx = _dragDx + d.delta.dx;
    // Nothing before the first question: let it give a little, no more.
    if (_isFirst && dx > 0) dx = _dragDx + d.delta.dx * 0.3;
    setState(() => _dragDx = dx.clamp(-width, width));
  }

  void _onDragEnd(DragEndDetails d, double width) {
    final velocity = d.primaryVelocity ?? 0;
    final double direction = velocity.abs() > _flingVelocity
        ? velocity.sign
        : (_dragDx.abs() > width * _swipeFraction ? _dragDx.sign : 0);
    if (widget.checking || direction == 0) return _snapBack();
    if (direction < 0) {
      // Left: forward. Past the last question this finishes the run.
      setState(() => _dragDx = 0);
      widget.onNext();
    } else if (!_isFirst) {
      setState(() => _dragDx = 0);
      widget.onPrevious();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_dragDx == 0) return;
    _snapFrom = _dragDx;
    _snap.forward(from: 0);
  }

  void _onSnapTick() {
    setState(() {
      _dragDx = _snapFrom * (1 - Curves.easeOut.transform(_snap.value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCheckBar = !_checksOnSelect && _verdict == null;
    return Column(
      children: [
        _header(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (d) => _onDragUpdate(d, box.maxWidth),
              onHorizontalDragEnd: (d) => _onDragEnd(d, box.maxWidth),
              onHorizontalDragCancel: _snapBack,
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _slide,
                  layoutBuilder: (current, previous) =>
                      Stack(children: [...previous, ?current]),
                  child: KeyedSubtree(
                    key: ValueKey(widget.number),
                    child: Transform.translate(
                      offset: Offset(_dragDx, 0),
                      // Opaque, so the question sliding out can never show
                      // through the one sliding in.
                      child: ColoredBox(
                        color: AppColors.scaffoldLight,
                        child: _questionList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showCheckBar) _checkBar(context),
      ],
    );
  }

  /// The incoming question slides in from the side the student swiped
  /// towards; the outgoing one leaves by the opposite side.
  ///
  /// Worked out on every frame, not once. [AnimatedSwitcher] builds a
  /// child's transition a single time — when it arrives — and plays that
  /// same transition backwards when the child leaves. A fixed "in from the
  /// right" therefore also left to the right, straight across the next
  /// question coming in from the right: the overlap. Reading the
  /// animation's status each frame tells arriving (forward) from leaving
  /// (reverse), and reading [_forward] each frame follows the direction of
  /// the swipe that is actually happening.
  Widget _slide(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final leaving =
            animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;
        final towards = _forward ? 1.0 : -1.0;
        // Arriving: from the far side to centre. Leaving: from centre to
        // the near side. `value` runs 0→1 arriving and 1→0 leaving.
        final side = leaving ? -towards : towards;
        return FractionalTranslation(
          translation: Offset(side * (1 - animation.value), 0),
          child: child,
        );
      },
    );
  }

  /// Edge to edge, no card: the whole question and its options should fit
  /// on one screen, so the student can tap without scrolling.
  Widget _questionList() {
    final passage = widget.item.passage;
    final instructions = (widget.item.sectionInstructions ?? '').trim();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingM + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        if (instructions.isNotEmpty) ...[
          ExamInstructionCallout(instructions, label: 'Section instructions'),
          const SizedBox(height: AppSizes.paddingS),
        ],
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
              compact: true,
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
          const SizedBox(height: 10),
          _verdictCard(_verdict!),
        ],
        _swipeHint(),
      ],
    );
  }

  /// Says how to move on, but only when it's useful: on the very first
  /// question (before the student has found the gesture), and once a
  /// question is answered (when moving on is the next thing to do).
  Widget _swipeHint() {
    final firstLook = widget.visited.length <= 1 && _verdict == null;
    if (!firstLook && _verdict == null) return const SizedBox.shrink();
    final text = _verdict == null
        ? 'Swipe left or right to move between questions'
        : (_isLast
              ? 'Swipe left to finish'
              : 'Swipe left for the next question');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_left_rounded, size: 16, color: AppColors.grey400),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  /// One slim row — position and section — over a thin progress bar. The
  /// grid button lives in the app bar ([showPracticeQuestionGrid]). The bar turns
  /// indeterminate while an answer is being checked.
  Widget _header(BuildContext context) {
    final progress = widget.total == 0
        ? 0.0
        : (widget.number / widget.total).clamp(0.0, 1.0);
    final section = widget.item.sectionName.trim();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(AppSizes.paddingM, 6, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${widget.number} / ${widget.total}',
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              if (section.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextSmallSemiBold.copyWith(
                      color: AppColors.mutedTextPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.paddingM),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              child: LinearProgressIndicator(
                value: widget.checking ? null : progress,
                minHeight: 4,
                backgroundColor: AppColors.grey100,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The comprehension passage this question is about.
  Widget _passageCard(ExamQuestion passage) {
    return ExamCard(
      padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.successBackground
            : AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct' : 'Wrong',
                style: AppTypography.bodyTextSemiBold.copyWith(color: accent),
              ),
              if (answerLine != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answerLine,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (verdict.hasSolution) ...[
            const SizedBox(height: 6),
            Text(
              'Explanation',
              style: AppTypography.bodyTextSmallSemiBold.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
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
        return null;
      case ExamQuestionType.trueFalse:
        final picked = widget.draft.boolean;
        if (picked == null) return null;
        return 'Answer: ${picked ? 'False' : 'True'}';
      default:
        return verdict.hasSolution ? null : 'Not the right answer.';
    }
  }

  // ── Check bar (typed answers only) ─────────────────────────────────────

  /// Only typed and multi-part answers need a button — a one-tap answer is
  /// checked by the tap itself, and moving on is a swipe.
  Widget _checkBar(BuildContext context) {
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
          onPressed: widget.checking || !_hasAnswer ? null : widget.onCheck,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFill,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.primaryFill.withValues(
              alpha: 0.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            ),
          ),
          child: widget.checking
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onPrimary,
                    ),
                  ),
                )
              : Text(
                  'Check answer',
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The practice review grid: right, wrong, skipped, this one, and not yet
/// seen. Every cell is tappable — practice is held locally, so any question
/// can be opened, answered or looked back at.
///
/// Opened from the exam page's app bar, so it takes the practice state's
/// fields rather than living inside [ExamPracticeView].
Future<void> showPracticeQuestionGrid(
  BuildContext context, {
  required int number,
  required int total,
  required Map<int, bool> outcomes,
  required Set<int> visited,
  required ValueChanged<int> onJumpTo,
  required VoidCallback onSubmit,
}) async {
  final current = number - 1;
  ExamPaletteStatus statusOf(int index) {
    if (index == current) return ExamPaletteStatus.current;
    final outcome = outcomes[index];
    if (outcome != null) {
      return outcome ? ExamPaletteStatus.correct : ExamPaletteStatus.wrong;
    }
    return visited.contains(index)
        ? ExamPaletteStatus.skipped
        : ExamPaletteStatus.upcoming;
  }

  var submit = false;
  final index = await showExamQuestionPalette(
    context,
    reviewMode: true,
    entries: [
      for (var i = 0; i < total; i++)
        ExamPaletteEntry(number: i + 1, status: statusOf(i)),
    ],
    footerBuilder: (sheetContext) => ExamSheetSubmitButton(
      sheetContext: sheetContext,
      onPressed: () => submit = true,
    ),
  );
  if (submit) {
    // Unanswered questions count as skipped — fine when meant, but a stray
    // tap would end the run, and practice keeps nothing to come back to.
    final left = total - outcomes.length;
    if (left > 0) {
      if (!context.mounted) return;
      final ok = await _confirmPracticeSubmit(context, left);
      if (ok != true) return;
    }
    onSubmit();
    return;
  }
  if (index == null || index == current) return;
  onJumpTo(index);
}

Future<bool?> _confirmPracticeSubmit(BuildContext context, int left) {
  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.overlayMedium,
    builder: (ctx) => ExamDialogShell(
      icon: Icons.task_alt_rounded,
      accent: AppColors.primary,
      title: 'Submit practice?',
      message: left == 1
          ? "1 question isn't answered yet. It will count as skipped."
          : "$left questions aren't answered yet. They will count as skipped.",
      actions: [
        ExamDialogAction(
          label: 'Submit',
          color: AppColors.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        ExamDialogGhostAction(
          label: 'Continue',
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
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
                  backgroundColor: AppColors.primaryFill,
                  foregroundColor: AppColors.onPrimary,
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
