import 'package:flutter/material.dart';

import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/draggable_fab.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_input.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_quiz_verdict.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_palette.dart';

/// Quiz mode: one question at a time, graded the moment it is answered.
///
/// This is the only screen in the exam flow that shows a student whether
/// they were right before they submit. A wrong answer can be changed by
/// spending a retry from the attempt's budget; retries cost rank on the
/// leaderboard, never marks — a corrected answer scores exactly what it
/// would have scored if it were right first time.
class ExamQuizView extends StatefulWidget {
  final CompetitiveQuestionResponse data;
  final ExamAnswerDraft draft;

  /// Null while the student is still choosing. Once set, the answer has
  /// been graded and this screen is showing the verdict.
  final QuizAnswerResultResponse? feedback;

  final bool submitting;
  final int retryPointsUsed;
  final int retryPoints;

  /// Options already tried and found wrong on this question.
  final Set<int> wrongOptionIds;

  /// 1-based numbers of the questions the student has pinned so far.
  final Set<int> pinnedQuestionNumbers;

  /// 1-based numbers this client can show again from its own cache.
  final Set<int> reviewableQuestionNumbers;

  /// Fetches one already-answered question to show back. Returns null for
  /// a question this client never served, e.g. on a resumed attempt.
  final QuizReviewEntry? Function(int questionNumber) onReviewQuestion;

  /// Changes the answer on an already-answered question. Costs a point and
  /// never moves the paper.
  final Future<QuizRevisionOutcome> Function(
    int questionNumber,
    ExamAnswerDraft draft,
  )
  onReviseQuestion;

  /// Pin / unpin a question by id. Takes the id rather than acting on
  /// "the current one" because the same control flags a question being
  /// looked back at.
  final ValueChanged<int> onTogglePin;

  final ValueChanged<ExamAnswerDraft> onAnswerChanged;

  /// Grade what is currently entered. [moveOn] accepts a wrong answer and
  /// advances without spending a retry.
  final void Function({bool moveOn}) onCheck;

  final VoidCallback onContinue;

  /// Spend [QuizPointCosts.reveal] points to be shown the answer and its
  /// explanation. The question then earns its marks, at a cost to rank.
  final VoidCallback onReveal;

  /// The same purchase, aimed at a question the paper has already gone
  /// past. Separate from [onReveal] because it names its target and the
  /// attempt must not move — see ExamCubit.revealQuizAnswerFor.
  final Future<QuizRevisionOutcome> Function(int questionNumber)
  onRevealQuestion;

  /// Asked once the screen is up; true means this is the student's first
  /// look at the quiz, so the rules open by themselves. Null never does.
  final Future<bool> Function()? shouldShowRulesOnOpen;

  const ExamQuizView({
    super.key,
    required this.data,
    required this.draft,
    required this.feedback,
    required this.submitting,
    required this.retryPointsUsed,
    required this.retryPoints,
    required this.wrongOptionIds,
    required this.pinnedQuestionNumbers,
    required this.reviewableQuestionNumbers,
    required this.onReviewQuestion,
    required this.onReviseQuestion,
    required this.onTogglePin,
    required this.onAnswerChanged,
    required this.onCheck,
    required this.onContinue,
    required this.onReveal,
    required this.onRevealQuestion,
    this.shouldShowRulesOnOpen,
  });

  @override
  State<ExamQuizView> createState() => _ExamQuizViewState();
}

class _ExamQuizViewState extends State<ExamQuizView> {
  // Aliases so the render code reads the same as it did before this
  // screen needed state of its own.
  CompetitiveQuestionResponse get data => widget.data;
  bool get submitting => widget.submitting || _reviewSaving;
  int get retryPointsUsed => widget.retryPointsUsed;
  int get retryPoints => widget.retryPoints;
  Set<int> get wrongOptionIds =>
      _reviewing == null ? widget.wrongOptionIds : const {};
  Set<int> get pinnedQuestionNumbers => widget.pinnedQuestionNumbers;
  Set<int> get reviewableQuestionNumbers => widget.reviewableQuestionNumbers;
  VoidCallback get onContinue => widget.onContinue;
  VoidCallback get onReveal => widget.onReveal;

  // ── Looking back at an earlier question ──────────────────────────────
  //
  // Held here rather than in the bloc, and rendered by this same screen
  // rather than a page of its own: the student asked to see question 1,
  // not to be moved somewhere that looks different. Everything around the
  // question — the exam title, the timer in the app bar, the flag, the
  // points chip, the progress button — stays exactly where it was.

  /// The earlier question on screen, or null when showing the live one.
  QuizReviewEntry? _reviewing;

  /// A typed answer being edited on the earlier question. One-tap answers
  /// never land here — a tap is the whole submission, so it goes straight
  /// to the price dialog.
  ExamAnswerDraft? _reviewDraft;

  bool _reviewSaving = false;
  String? _reviewError;

  bool get _isReviewing => _reviewing != null;

  @override
  void initState() {
    super.initState();
    final ask = widget.shouldShowRulesOnOpen;
    if (ask == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await ask() && mounted) _showRules();
    });
  }

  @override
  void didUpdateWidget(ExamQuizView old) {
    super.didUpdateWidget(old);
    // A fresh verdict that cost points gets a short toast rather than a
    // dialog up front — the student keeps their focus on the question.
    final fresh = widget.feedback;
    if (fresh != null && !identical(fresh, old.feedback)) {
      _announceSpend(fresh);
    }
    // The paper moved underneath us (a section transition, or the deadline
    // submitting). Whatever was being looked at no longer applies.
    if (old.data.questionNumber != widget.data.questionNumber) {
      _reviewing = null;
      _reviewDraft = null;
      _reviewError = null;
    }
  }

  /// The question on screen: the one being looked back at, else the live
  /// one.
  ExamQuestion? get _question => _reviewing?.question ?? data.question;

  /// Its 1-based number.
  int get _number => _reviewing?.number ?? data.questionNumber;

  /// The answer on screen — the edit in progress, the answer given
  /// earlier, or the live draft.
  ExamAnswerDraft get _draft =>
      _reviewing == null ? widget.draft : (_reviewDraft ?? _reviewing!.answer);

  /// The verdict on screen. Safe to leave up while they pick again: it
  /// never carries the correct answer unless it was earned or paid for.
  QuizAnswerResultResponse? get _feedback =>
      _reviewing == null ? widget.feedback : _reviewing!.outcome;

  /// Whether the earlier question on screen is still open to a change.
  bool get _canReviseHere =>
      _isReviewing && _reviewing!.canRevise(_pointsRemaining);

  /// The question on screen settled without the student ever answering
  /// it. A skip is not a wrong answer, and answering it later is still
  /// their first try — so it costs nothing and isn't shown as a mistake.
  bool get _isUnattempted {
    if (_isReviewing) return _reviewing!.wasUnattempted;
    final shown = widget.feedback;
    return shown != null && !shown.answerRevealed && widget.draft.isEmpty;
  }

  /// What answering the question on screen costs right now.
  int get _answerCost =>
      _isReviewing ? _reviewing!.revisionCost : QuizPointCosts.retry;

  /// Whether picking an option is itself the answer — the whole point of
  /// quiz mode is the instant verdict, so for one-tap question types there
  /// is no "Check answer" step between the tap and the result.
  ///
  /// Typed and multi-part answers (integer, blanks, select-all, matching)
  /// aren't finished at the first tap, so those keep an explicit button.
  bool get _checksOnSelect {
    final type = _question?.questionType;
    return type == ExamQuestionType.multipleChoice ||
        type == ExamQuestionType.trueFalse;
  }

  /// Points still on the table. Read from the latest response while one
  /// is showing — it is what the server just charged.
  int get _pointsRemaining =>
      widget.feedback?.pointsRemaining ??
      (retryPoints - retryPointsUsed).clamp(0, retryPoints);

  /// A reveal is only offered while the student can still afford it; the
  /// server refuses one below the price anyway.
  bool get _canAffordReveal => _pointsRemaining >= QuizPointCosts.reveal;

  /// Whether the answer on screen is wrong but still open — picking again
  /// is the retry, so the inputs stay live and the verdict stays up.
  bool get _canPickAgain {
    if (_isReviewing) return false;
    final shown = widget.feedback;
    return shown != null && shown.canRetry && !shown.advanced;
  }

  /// The inputs are read-only: the question is settled, or it is an
  /// earlier one being read rather than changed.
  bool get _locked => _isReviewing
      ? !_canReviseHere
      : (widget.feedback != null && !_canPickAgain);

  @override
  Widget build(BuildContext context) {
    final question = _question;
    final progress = data.totalQuestions == 0
        ? 0.0
        : (_number / data.totalQuestions).clamp(0.0, 1.0);

    return Column(
      children: [
        _header(progress),
        Expanded(
          child: question == null
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ExamDraftScope(
                        // One live draft for the current question (and any
                        // comprehension children resolve to it too).
                        resolver: (_) => _draft,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.paddingM,
                            AppSizes.paddingS,
                            AppSizes.paddingM,
                            AppSizes.paddingM,
                          ),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ExamSectionHeader(
                                    name:
                                        _reviewing?.sectionName ??
                                        data.sectionName ??
                                        'Section',
                                  ),
                                ),
                                _rulesButton(),
                              ],
                            ),
                            if (!_isReviewing &&
                                (data.sectionInstructions ?? '')
                                    .trim()
                                    .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.paddingS,
                                ),
                                child: ExamInstructionCallout(
                                  data.sectionInstructions!,
                                  label: 'Section instructions',
                                ),
                              ),
                            if (_isReviewing) ...[
                              _reviewBanner(),
                              const SizedBox(height: AppSizes.paddingS),
                            ],
                            // Absorbing pointers rather than making every input
                            // type read-only: once graded, nothing on the
                            // question should respond until the student either
                            // spends a retry or moves on.
                            AbsorbPointer(
                              absorbing: _locked || submitting,
                              child: ExamQuestionInput(
                                question: question,
                                number: _number,
                                draft: _draft,
                                onChanged: (_, d) => _handleDraft(d),
                                quizFeedback: ExamQuizFeedback(
                                  correctOptionId:
                                      _feedback?.shownCorrectOptionId,
                                  wrongOptionIds: wrongOptionIds,
                                ),
                              ),
                            ),
                            if (_feedback != null) ...[
                              const SizedBox(height: AppSizes.paddingM),
                              ExamQuizVerdictCard(
                                result: _feedback!,
                                retryPoints: retryPoints,
                                unattempted: _isUnattempted,
                              ),
                            ],
                            if (_reviewError != null) ...[
                              const SizedBox(height: AppSizes.paddingS),
                              _errorNote(_reviewError!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DraggableFab(
                        margin: const EdgeInsets.all(AppSizes.paddingM),
                        builder: (ctx, _) => ExamStatsFab(
                          pinnedCount: pinnedQuestionNumbers.length,
                          onTap: () => _openProgress(ctx),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        _actionBar(context),
      ],
    );
  }

  /// A change while a verdict is on screen is ignored upstream; this only
  /// decides whether the change should also be graded straight away.
  void _handleDraft(ExamAnswerDraft next) {
    if (_locked || submitting) return;
    if (_isReviewing) {
      if (!_canReviseHere) return;
      // A tap is the whole submission on a one-tap type, so it lands
      // straight away; the point it cost is announced after, not asked
      // about before. Typed answers are edited freely until Save.
      if (!_checksOnSelect) {
        setState(() => _reviewDraft = next);
        return;
      }
      _saveRevision(next);
      return;
    }
    widget.onAnswerChanged(next);
    // A typed answer waits for Check; a tap is the answer — first try or
    // retry alike. A retry's point is announced once the server charges it.
    if (_checksOnSelect) widget.onCheck();
  }

  // ── Rules and spend toasts ─────────────────────────────────────────────

  /// Info button at the end of the section row: the quiz rules on demand,
  /// instead of a banner taking up space above every question.
  Widget _rulesButton() {
    return IconButton(
      onPressed: _showRules,
      tooltip: 'How this quiz works',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.info_outline_rounded, color: AppColors.primary),
    );
  }

  Future<void> _showRules() {
    final hasPoints = retryPoints > 0;
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayMedium,
      builder: (ctx) => ExamDialogShell(
        icon: Icons.bolt_rounded,
        accent: AppColors.primary,
        title: 'How this quiz works',
        message: hasPoints
            ? 'You have $_pointsRemaining points to use.'
            : 'There are no points on this exam, so each answer is final.',
        extra: Column(
          children: [
            _ruleRow(
              Icons.check_circle_outline_rounded,
              'See instantly if you are right',
            ),
            if (hasPoints) ...[
              _ruleRow(
                Icons.replay_rounded,
                'Wrong? Try again · ${QuizPointCosts.retry} pt',
              ),
              _ruleRow(
                Icons.lightbulb_outline_rounded,
                'Hint shows the answer · ${QuizPointCosts.reveal} pts',
              ),
            ],
            _ruleRow(Icons.skip_next_rounded, 'Skip anytime · free'),
            if (hasPoints)
              _ruleRow(
                Icons.leaderboard_rounded,
                'Points affect your rank, not your marks',
              ),
          ],
        ),
        actions: [
          ExamDialogAction(
            label: 'Got it',
            color: AppColors.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A short toast for any verdict that spent points: what it cost and
  /// what is left. Free answers and skips say nothing.
  void _announceSpend(QuizAnswerResultResponse res) {
    final String title;
    if (res.answerRevealed) {
      title = 'Hint used · −${QuizPointCosts.reveal} pts';
    } else if (res.pointsSpent) {
      title = 'Retry · −${QuizPointCosts.retry} pt';
    } else {
      return;
    }
    final left = res.pointsRemaining;
    // Deferred: this can run from didUpdateWidget, mid-build, and the
    // toast inserts itself into the overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CustomSnackbar.warning(
        context,
        title: title,
        message: left == 1 ? '1 point left' : '$left points left',
        duration: const Duration(seconds: 2),
      );
    });
  }

  /// Skipping costs nothing and settles nothing the student can't undo —
  /// the question can still be answered later from the progress grid — so
  /// it goes straight through. Only spends get a confirmation.
  void _skip() => widget.onCheck(moveOn: true);

  // ── Header ─────────────────────────────────────────────────────────────

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
          // No exam title here: the app bar already carries it.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question $_number of ${data.totalQuestions}',
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              // Lives here rather than on the question card because the
              // card is behind an AbsorbPointer once the answer is graded,
              // and being graded is exactly when a student wants to flag
              // the question.
              _pinToggle(),
              // Only shown when the exam actually grants points — a
              // permanent "0 left" on an exam that never had any would
              // read as something the student had spent.
              if (retryPoints > 0) ...[
                const SizedBox(width: 6),
                ExamChip(
                  _pointsRemaining == 1
                      ? '1 point left'
                      : '$_pointsRemaining points left',
                  color: _pointsRemaining > 0
                      ? AppColors.warning
                      : AppColors.mutedTextPrimary,
                  icon: Icons.toll_outlined,
                ),
              ],
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

  /// Flag the current question. In quiz mode a pin can't mean "come back
  /// to this" — the paper only moves forward — so it means "show me this
  /// again on the result screen", which is where the pins resurface.
  Widget _pinToggle() {
    final pinned = pinnedQuestionNumbers.contains(_number);
    final color = pinned ? AppColors.warning : AppColors.mutedTextPrimary;
    return Tooltip(
      message: pinned
          ? 'Flagged. You will see this again on your result'
          : 'Flag this question to review after the exam',
      child: Material(
        color: pinned
            ? AppColors.warning.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        child: InkWell(
          onTap: () {
            final id = _question?.id;
            if (id != null) widget.onTogglePin(id);
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              border: Border.all(
                color: pinned
                    ? AppColors.warning.withValues(alpha: 0.45)
                    : AppColors.dividerLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  pinned ? 'Flagged' : 'Flag',
                  style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Progress grid. Quiz mode is paced by the server, so tapping a cell
  /// can't move the paper — but a question this client has already served
  /// and seen settle can be shown again from cache, which is what the
  /// student actually wants when they tap "1" from question 3.
  ///
  /// Only those cells respond. The current question closes the sheet (they
  /// are already on it) and the ones still to come do nothing.
  Future<void> _openProgress(BuildContext context) async {
    final index = await showExamQuestionPalette(
      context,
      reviewMode: false,
      jumpable: false,
      entries: [
        for (var i = 1; i <= data.totalQuestions; i++)
          ExamPaletteEntry(
            number: i,
            status: i < data.questionNumber
                ? _pastStatus(i)
                : (i == data.questionNumber
                      ? ExamPaletteStatus.current
                      : ExamPaletteStatus.upcoming),
            pinned: pinnedQuestionNumbers.contains(i),
            selectable:
                i == data.questionNumber ||
                reviewableQuestionNumbers.contains(i),
          ),
      ],
    );
    if (index == null || !mounted) return;
    final number = index + 1;
    if (number == data.questionNumber) {
      // Back to the live question.
      _closeReview();
      return;
    }
    final entry = widget.onReviewQuestion(number);
    if (entry == null) return;
    setState(() {
      _reviewing = entry;
      _reviewDraft = null;
      _reviewError = null;
    });
  }

  /// A question the paper has gone past: grey if it was skipped, green
  /// otherwise. Only questions this client served can be told apart — on a
  /// resumed attempt the earlier ones stay green, as nothing is known.
  ExamPaletteStatus _pastStatus(int number) =>
      widget.onReviewQuestion(number)?.wasUnattempted == true
      ? ExamPaletteStatus.skipped
      : ExamPaletteStatus.answered;

  void _closeReview() {
    if (!_isReviewing) return;
    setState(() {
      _reviewing = null;
      _reviewDraft = null;
      _reviewError = null;
    });
  }

  Future<void> _saveRevision(ExamAnswerDraft draft) async {
    final entry = _reviewing;
    if (entry == null || _reviewSaving) return;
    setState(() {
      _reviewSaving = true;
      _reviewError = null;
    });
    final outcome = await widget.onReviseQuestion(entry.number, draft);
    if (!mounted) return;
    if (outcome.attemptEnded) {
      // Time ran out while they were back here; the attempt is grading.
      setState(() {
        _reviewing = null;
        _reviewDraft = null;
        _reviewSaving = false;
      });
      return;
    }
    if (outcome.ok) _announceSpend(outcome.entry!.outcome);
    setState(() {
      _reviewSaving = false;
      if (outcome.ok) {
        _reviewing = outcome.entry;
        _reviewDraft = null;
      } else {
        // Keep the edit: losing what they typed on a refusal would be a
        // second punishment.
        _reviewError = outcome.error ?? 'Could not change your answer.';
      }
    });
  }

  Widget _reviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Looking back at question $_number. You are still on question '
              '${data.questionNumber}; nothing here moves the exam on.',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorNote(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Verdict ────────────────────────────────────────────────────────────

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
      child: _actions(context),
    );
  }

  Widget _actions(BuildContext context) {
    if (_isReviewing) return _reviewActions(context);
    final result = widget.feedback;

    // Settled — the server has advanced, so the only way is onward.
    if (result != null && !_canPickAgain) {
      final last = result.finished || data.isLast;
      return _primaryButton(
        label: last ? 'Finish exam' : 'Next question',
        icon: last ? Icons.check : Icons.arrow_forward,
        enabled: !submitting,
        onPressed: onContinue,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A one-tap question has no submit of its own — the tap is the
        // answer — so it gets a line of guidance instead of a button.
        if (_checksOnSelect)
          _hint(
            submitting
                ? 'Checking your answer…'
                : _canPickAgain
                ? 'Tap another option to retry · ${QuizPointCosts.retry} pt'
                : 'Pick an option to check it instantly.',
          )
        else
          _primaryButton(
            label: _canPickAgain
                ? 'Check answer · ${QuizPointCosts.retry} pt'
                : 'Check answer',
            icon: Icons.fact_check_outlined,
            // Nothing entered is nothing to grade, and would spend a
            // point on a no-op.
            enabled: !_isDraftEmptyForQuestion,
            onPressed: () => widget.onCheck(),
          ),
        const SizedBox(height: 8),
        // Both always on screen, so neither has to be discovered. An exam
        // with no points budget has no hint to offer, so skip takes the
        // whole width rather than sitting next to a control that can
        // never do anything.
        if (retryPoints == 0)
          _skipButton()
        else
          Row(
            children: [
              Expanded(child: _hintButton(context, compact: true)),
              const SizedBox(width: 8),
              Expanded(child: _skipButton()),
            ],
          ),
        _shortfallNote(),
      ],
    );
  }

  /// Settle the question as it stands and move on. Free, and the counter-
  /// weight to the hint: the way out for a student who would rather keep
  /// their points than their marks on this one.
  Widget _skipButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: submitting ? null : _skip,
        icon: Icon(
          Icons.skip_next_rounded,
          size: 18,
          color: AppColors.mutedTextPrimary,
        ),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Skip · free',
            maxLines: 1,
            style: AppTypography.bodyTextSmallSemiBold.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mutedTextPrimary,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.dividerLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
      ),
    );
  }

  /// The look-back's controls. No retry button: picking a different
  /// option is the retry, exactly as on the live question. Hint keeps its
  /// slot (dead — reveal only ever applies to the question the server is
  /// on), and the way back takes the place skip holds on a live question.
  Widget _reviewActions(BuildContext context) {
    final entry = _reviewing!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_checksOnSelect && _canReviseHere)
          _primaryButton(
            label: _answerCost == 0
                ? 'Save answer'
                : 'Save change · ${QuizPointCosts.retry} pt',
            icon: Icons.check,
            // Nothing entered is nothing to grade, and would spend the
            // point on a no-op.
            enabled: _reviewDraft != null && !_isDraftEmptyForQuestion,
            onPressed: () => _saveRevision(_draft),
          )
        else
          _hint(
            !_canReviseHere
                ? 'This question is settled.'
                : _answerCost == 0
                ? 'You skipped this one. Answering it now is free.'
                : 'Tap another option to retry · ${QuizPointCosts.retry} pt',
          ),
        const SizedBox(height: 8),
        if (retryPoints == 0)
          _backButton()
        else
          Row(
            children: [
              Expanded(child: _hintButton(context, compact: true)),
              const SizedBox(width: 8),
              Expanded(child: _backButton()),
            ],
          ),
        _reviewNote(entry),
      ],
    );
  }

  /// Out of the look-back and on to wherever the exam actually is. Sits
  /// where skip sits on a live question — both are "leave this one".
  Widget _backButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: submitting ? null : _closeReview,
        icon: Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Back to Q${data.questionNumber}',
            maxLines: 1,
            style: AppTypography.bodyTextSmallSemiBold.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
      ),
    );
  }

  /// Why the controls above are dead, when they are. Said plainly — a
  /// greyed button with no reason reads as a bug.
  Widget _reviewNote(QuizReviewEntry entry) {
    final String? reason;
    if (entry.outcome.answerRevealed) {
      reason =
          'You bought this answer, so it keeps its marks and there is '
          'nothing left to change.';
    } else if (entry.outcome.isCorrect) {
      reason = 'You already got this right.';
    } else if (entry.question.isComprehension) {
      reason = 'Change the sub-questions individually.';
    } else if (_pointsRemaining < entry.revisionCost) {
      reason =
          'Changing an answer costs ${QuizPointCosts.retry} point. You have '
          '$_pointsRemaining.';
    } else if (retryPoints > 0 && !_canAffordReveal) {
      // Answering is still within reach here — only the hint is out of
      // budget — so the greyed hint needs its own reason rather than
      // sharing the revision one above.
      reason =
          'A hint costs ${QuizPointCosts.reveal} points. You have '
          '$_pointsRemaining.';
    } else {
      reason = null;
    }
    if (reason == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        reason,
        textAlign: TextAlign.center,
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.mutedTextPrimary,
        ),
      ),
    );
  }

  /// The hint control: spends [QuizPointCosts.reveal] points to show the
  /// answer and its explanation.
  ///
  /// Outlined rather than solid — it shouldn't out-shout answering the
  /// question — but it carries its price on the face and is never hidden,
  /// so a stuck student can find it. Confirmed before it fires, because
  /// the spend is irreversible and is what the ranking penalty prices.
  ///
  /// [compact] is the half-width form used beside another button; the
  /// "why is this disabled" line moves out to [_shortfallNote] there,
  /// because it cannot fit on the face.
  Widget _hintButton(BuildContext context, {bool compact = false}) {
    // On a look-back the hint buys the answer to *that* question, so it is
    // offered wherever the answer is not already the student's:
    // `isRevisable` is false once they got it right or already paid, and
    // on a comprehension parent, which the server refuses by id.
    final affordable =
        _canAffordReveal && (!_isReviewing || _reviewing!.isRevisable);
    final accent = affordable ? AppColors.warning : AppColors.mutedTextPrimary;
    final label = (affordable || compact)
        ? 'Hint · ${QuizPointCosts.reveal} pts'
        : 'Hint · needs ${QuizPointCosts.reveal} points '
              '(you have $_pointsRemaining)';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (submitting || !affordable) ? null : _useHint,
        icon: Icon(Icons.lightbulb_outline_rounded, size: 18, color: accent),
        // Narrow phones shrink the label rather than clipping it.
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: AppTypography.bodyTextSmallSemiBold.copyWith(color: accent),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          backgroundColor: affordable
              ? AppColors.warning.withValues(alpha: 0.08)
              : null,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(
            color: affordable
                ? AppColors.warning.withValues(alpha: 0.55)
                : AppColors.dividerLight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
      ),
    );
  }

  /// Why the hint is dead, said under a paired row. Only the compact
  /// button needs this — it has no room for the reason on its face, and a
  /// greyed control with no reason reads as a bug.
  Widget _shortfallNote() {
    if (retryPoints == 0 || _canAffordReveal) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'A hint costs ${QuizPointCosts.reveal} points. You have '
        '$_pointsRemaining.',
        textAlign: TextAlign.center,
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.mutedTextPrimary,
        ),
      ),
    );
  }

  /// Spends the hint straight away — the price is on the button's face,
  /// and what it cost is confirmed by a toast rather than asked about.
  Future<void> _useHint() async {
    if (_isReviewing) {
      await _revealReviewed();
    } else {
      onReveal();
    }
  }

  /// Buy the answer to the question being looked back at. Mirrors
  /// [_saveRevision]: the sheet stays open on the refreshed entry, and a
  /// refusal is shown in place rather than thrown at the exam screen.
  Future<void> _revealReviewed() async {
    final entry = _reviewing;
    if (entry == null || _reviewSaving) return;
    setState(() {
      _reviewSaving = true;
      _reviewError = null;
    });
    final outcome = await widget.onRevealQuestion(entry.number);
    if (!mounted) return;
    if (outcome.attemptEnded) {
      setState(() {
        _reviewing = null;
        _reviewDraft = null;
        _reviewSaving = false;
      });
      return;
    }
    if (outcome.ok) _announceSpend(outcome.entry!.outcome);
    setState(() {
      _reviewSaving = false;
      if (outcome.ok) {
        _reviewing = outcome.entry;
        // The answer is on screen now; a half-typed one is meaningless.
        _reviewDraft = null;
      } else {
        _reviewError = outcome.error ?? 'Could not show the answer.';
      }
    });
  }

  /// Whether there is anything to grade. Mirrors the wire shape — an answer
  /// that serialises to nothing is what the server counts as unattempted.
  bool get _isDraftEmptyForQuestion {
    final question = _question;
    if (question == null) return true;
    return _draft.toRequestJson(question.id, question.questionType) == null;
  }

  Widget _hint(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (submitting) ...[
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
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled && !submitting ? onPressed : null,
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
