import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/draggable_fab.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_input.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_palette.dart';

/// The normal-mode paper, paginated one section at a time.
///
/// Multi-section exams show a single section per page with Back / Next
/// navigation; the last section swaps Next for Submit. Single-section
/// exams simply show Submit (no Back / Next). Question numbering stays
/// continuous across sections, and answer drafts persist in the cubit so
/// paging back and forth repaints previous answers.
class ExamPaperView extends StatefulWidget {
  final ExamPaperResponse paper;
  final Map<int, ExamAnswerDraft> answers;
  final bool autosaveStopped;

  /// Top-level question ids parked for a second look.
  final Set<int> pinnedQuestionIds;

  final void Function(int questionId, ExamAnswerDraft draft) onUpdateAnswer;
  final ValueChanged<int> onTogglePin;
  final VoidCallback onClearPins;
  final VoidCallback onSubmit;

  const ExamPaperView({
    super.key,
    required this.paper,
    required this.answers,
    required this.autosaveStopped,
    required this.pinnedQuestionIds,
    required this.onUpdateAnswer,
    required this.onTogglePin,
    required this.onClearPins,
    required this.onSubmit,
  });

  @override
  State<ExamPaperView> createState() => _ExamPaperViewState();
}

class _ExamPaperViewState extends State<ExamPaperView> {
  int _sectionIndex = 0;
  final ScrollController _scrollController = ScrollController();

  /// One key per top-level question, so the palette can scroll straight to
  /// it. Keyed by question id because the section on screen changes.
  final Map<int, GlobalKey> _questionKeys = {};

  /// The question the palette last jumped to, highlighted for a moment so
  /// the jump is visible. A short section may have only a few pixels of
  /// scroll (or none at all), in which case the scroll alone tells the
  /// student nothing about where they landed.
  int? _highlightedQuestionId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _highlight(int questionId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedQuestionId = questionId);
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightedQuestionId = null);
    });
  }

  List<ExamSection> get _sections => widget.paper.sections;

  GlobalKey _keyFor(int questionId) =>
      _questionKeys.putIfAbsent(questionId, () => GlobalKey());

  /// 1-based number of the first top-level question in [sectionIndex],
  /// used to keep numbering continuous across sections.
  int _startNumberFor(int sectionIndex) {
    var total = 0;
    for (var i = 0; i < sectionIndex; i++) {
      total += _sections[i].questions.length;
    }
    return total;
  }

  /// Counted over top-level questions so it lines up with the denominator
  /// (`paper.totalQuestions`) and with the palette's own tally.
  int get _answeredCount {
    var count = 0;
    for (final q in widget.paper.allQuestions) {
      if (_statusOf(q) == ExamPaletteStatus.answered) count++;
    }
    return count;
  }

  bool _isAnswered(int questionId) =>
      !(widget.answers[questionId] ?? const ExamAnswerDraft()).isEmpty;

  /// A comprehension block has no answer of its own — it reports on its
  /// children, and counts as done only once every one of them is filled in.
  ExamPaletteStatus _statusOf(ExamQuestion q) {
    if (q.isComprehension) {
      if (q.children.isEmpty) return ExamPaletteStatus.unanswered;
      final done = q.children.where((c) => _isAnswered(c.id)).length;
      if (done == 0) return ExamPaletteStatus.unanswered;
      if (done == q.children.length) return ExamPaletteStatus.answered;
      return ExamPaletteStatus.partial;
    }
    return _isAnswered(q.id)
        ? ExamPaletteStatus.answered
        : ExamPaletteStatus.unanswered;
  }

  /// Palette cells in paper order — the same 1..N numbering the question
  /// badges use, running continuously across sections.
  List<ExamPaletteEntry> _paletteEntries() {
    final out = <ExamPaletteEntry>[];
    for (final section in _sections) {
      for (final q in section.questions) {
        out.add(
          ExamPaletteEntry(
            number: out.length + 1,
            status: _statusOf(q),
            pinned: widget.pinnedQuestionIds.contains(q.id),
          ),
        );
      }
    }
    return out;
  }

  /// Which section a global (0-based) question index lives in, and the
  /// question itself.
  (int, ExamQuestion)? _locate(int globalIndex) {
    var seen = 0;
    for (var s = 0; s < _sections.length; s++) {
      final questions = _sections[s].questions;
      if (globalIndex < seen + questions.length) {
        return (s, questions[globalIndex - seen]);
      }
      seen += questions.length;
    }
    return null;
  }

  void _goTo(int index) {
    setState(() => _sectionIndex = index.clamp(0, _sections.length - 1));
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Paging to the right section and then scrolling the question into view.
  Future<void> _jumpToQuestion(int globalIndex) async {
    final located = _locate(globalIndex);
    if (located == null) return;
    final (sectionIndex, question) = located;

    if (sectionIndex != _sectionIndex) {
      // The scroll view is keyed by section, so it remounts at offset 0 and
      // the target's render object only exists after the next frame.
      setState(() => _sectionIndex = sectionIndex);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final ctx = _questionKeys[question.id]?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.05,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _highlight(question.id);
  }

  Future<void> _openPalette() async {
    final index = await showExamQuestionPalette(
      context,
      entries: _paletteEntries(),
      reviewMode: false,
    );
    if (index == null || !mounted) return;
    await _jumpToQuestion(index);
  }

  @override
  Widget build(BuildContext context) {
    // Guard against an out-of-range index if the paper somehow changes.
    if (_sectionIndex >= _sections.length) _sectionIndex = 0;

    final bool multi = _sections.length > 1;
    final bool isLast = _sectionIndex >= _sections.length - 1;
    final section = _sections.isEmpty ? null : _sections[_sectionIndex];
    final startNumber = _startNumberFor(_sectionIndex);

    return Column(
      children: [
        if (widget.autosaveStopped) _timeUpBanner(),
        if (multi) _sectionProgress(section),
        Expanded(
          child: section == null
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ExamDraftScope(
                        resolver: (id) =>
                            widget.answers[id] ?? const ExamAnswerDraft(),
                        // A plain scroll view rather than a lazy list: every
                        // question needs a laid-out render object for the
                        // palette to scroll straight to it.
                        child: SingleChildScrollView(
                          key: ValueKey(_sectionIndex),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.paddingM,
                            AppSizes.paddingS,
                            AppSizes.paddingM,
                            AppSizes.paddingM,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!multi) _summaryCard(),
                              if (!multi)
                                const SizedBox(height: AppSizes.paddingS),
                              ExamSectionHeader(
                                name: section.name,
                                trailing: '${section.questions.length}',
                              ),
                              if ((section.instructions ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSizes.paddingS,
                                  ),
                                  child: ExamInstructionCallout(
                                    section.instructions!,
                                    label: 'Section instructions',
                                  ),
                                ),
                              for (var i = 0; i < section.questions.length; i++)
                                Padding(
                                  key: _keyFor(section.questions[i].id),
                                  padding: const EdgeInsets.only(
                                    bottom: AppSizes.paddingM,
                                  ),
                                  child: ExamQuestionInput(
                                    question: section.questions[i],
                                    number: startNumber + i + 1,
                                    draft:
                                        widget.answers[section
                                            .questions[i]
                                            .id] ??
                                        const ExamAnswerDraft(),
                                    onChanged: widget.onUpdateAnswer,
                                    isPinned: widget.pinnedQuestionIds.contains(
                                      section.questions[i].id,
                                    ),
                                    onTogglePin: () => widget.onTogglePin(
                                      section.questions[i].id,
                                    ),
                                    onNumberTap: _openPalette,
                                    isHighlighted:
                                        _highlightedQuestionId ==
                                        section.questions[i].id,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DraggableFab(
                        margin: const EdgeInsets.all(AppSizes.paddingM),
                        builder: (context, _) => ExamStatsFab(
                          pinnedCount: widget.pinnedQuestionIds.length,
                          onTap: _openPalette,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        _navBar(context, isLast: isLast, hasBack: _sectionIndex > 0),
      ],
    );
  }

  // ── Section progress header ────────────────────────────────────────────

  Widget _sectionProgress(ExamSection? section) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Section ${_sectionIndex + 1} of ${_sections.length}',
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                'Answered $_answeredCount / ${widget.paper.totalQuestions}',
                style: AppTypography.bodyTextSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Segmented progress: one bar per section.
          Row(
            children: [
              for (var i = 0; i < _sections.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _sectionIndex
                          ? AppColors.primary
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          _metaPill(
            Icons.help_outline,
            '${widget.paper.totalQuestions} Questions',
          ),
          const SizedBox(width: 8),
          _metaPill(Icons.star_outline, '${widget.paper.totalMarks} Marks'),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodyTextSmallSemiBold.copyWith(
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _timeUpBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.errorBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Time's up. Submit now to grade your saved answers.",
              style: AppTypography.bodyTextSmallSemiBold.copyWith(
                color: AppColors.errorDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation / submit bar ─────────────────────────────────────

  Widget _navBar(
    BuildContext context, {
    required bool isLast,
    required bool hasBack,
  }) {
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
      child: Row(
        children: [
          if (hasBack) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goTo(_sectionIndex - 1),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: Text(
                  'Back',
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.paddingS),
          ],
          Expanded(
            child: isLast
                ? _primaryButton(
                    label: 'Submit Exam',
                    icon: Icons.check_circle_outline,
                    onPressed: _confirmSubmit,
                  )
                : _primaryButton(
                    label: 'Next Section',
                    icon: Icons.chevron_right,
                    trailingIcon: true,
                    onPressed: () => _goTo(_sectionIndex + 1),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool trailingIcon = false,
  }) {
    final textWidget = Text(
      label,
      style: AppTypography.bodyTextLargeSemiBold.copyWith(
        color: AppColors.alwaysWhite,
      ),
    );
    final iconWidget = Icon(icon, size: 20, color: AppColors.alwaysWhite);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.alwaysWhite,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: trailingIcon
            ? [textWidget, const SizedBox(width: 6), iconWidget]
            : [iconWidget, const SizedBox(width: 6), textWidget],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    // Pins are a promise to come back. Make good on it before the paper
    // closes, rather than letting Submit quietly discard them.
    if (widget.pinnedQuestionIds.isNotEmpty) {
      final entries = _paletteEntries();
      final pinnedEntries = <ExamPaletteEntry>[];
      final pinnedIndexes = <int>[];
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].pinned) {
          pinnedEntries.add(entries[i]);
          pinnedIndexes.add(i);
        }
      }
      final outcome = await showExamPinnedGate(
        context,
        pinnedEntries: pinnedEntries,
        pinnedIndexes: pinnedIndexes,
      );
      if (!mounted) return;
      // Dismissed or "Skip" — stay on the paper.
      if (outcome == null) return;
      if (outcome.jumpToIndex != null) {
        await _jumpToQuestion(outcome.jumpToIndex!);
        return;
      }
      widget.onClearPins();
    }

    if (!mounted) return;
    final answered = _answeredCount;
    final unanswered = widget.paper.totalQuestions - answered;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayMedium,
      builder: (ctx) => ExamDialogShell(
        icon: unanswered > 0
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded,
        accent: unanswered > 0 ? AppColors.warning : AppColors.primary,
        title: 'Submit exam?',
        message: unanswered > 0
            ? "You still have unanswered questions. Once submitted you can't "
                  'change your answers.'
            : "You've answered everything. Once submitted you can't change "
                  'your answers.',
        extra: _submitSummary(answered: answered, unanswered: unanswered),
        actions: [
          ExamDialogAction(
            label: 'Submit exam',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          ExamDialogGhostAction(
            label: 'Keep working',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onSubmit();
  }

  Widget _submitSummary({required int answered, required int unanswered}) {
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            value: '$answered',
            label: 'Answered',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(
          child: _summaryTile(
            value: '$unanswered',
            label: 'Unanswered',
            color: unanswered > 0 ? AppColors.warning : AppColors.grey400,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.bodyTextXtraLargeBold.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodyTextSmallMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
