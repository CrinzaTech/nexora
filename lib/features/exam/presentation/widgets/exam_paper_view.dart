import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_question_input.dart';

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
  final void Function(int questionId, ExamAnswerDraft draft) onUpdateAnswer;
  final VoidCallback onSubmit;

  const ExamPaperView({
    super.key,
    required this.paper,
    required this.answers,
    required this.autosaveStopped,
    required this.onUpdateAnswer,
    required this.onSubmit,
  });

  @override
  State<ExamPaperView> createState() => _ExamPaperViewState();
}

class _ExamPaperViewState extends State<ExamPaperView> {
  int _sectionIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<ExamSection> get _sections => widget.paper.sections;

  /// 1-based number of the first top-level question in [sectionIndex],
  /// used to keep numbering continuous across sections.
  int _startNumberFor(int sectionIndex) {
    var total = 0;
    for (var i = 0; i < sectionIndex; i++) {
      total += _sections[i].questions.length;
    }
    return total;
  }

  int get _answeredCount {
    var count = 0;
    for (final entry in widget.answers.entries) {
      if (!entry.value.isEmpty) count++;
    }
    return count;
  }

  void _goTo(int index) {
    setState(() => _sectionIndex = index.clamp(0, _sections.length - 1));
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
              : ExamDraftScope(
                  resolver: (id) =>
                      widget.answers[id] ?? const ExamAnswerDraft(),
                  child: ListView(
                    key: ValueKey(_sectionIndex),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.paddingS,
                      AppSizes.paddingM,
                      AppSizes.paddingM,
                    ),
                    children: [
                      if (!multi) _summaryCard(),
                      if (!multi) const SizedBox(height: AppSizes.paddingS),
                      ExamSectionHeader(
                        name: section.name,
                        trailing: '${section.questions.length}',
                      ),
                      if ((section.instructions ?? '').trim().isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSizes.paddingS),
                          child: ExamInstructionCallout(
                            section.instructions!,
                            label: 'Section instructions',
                          ),
                        ),
                      for (var i = 0; i < section.questions.length; i++)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSizes.paddingM),
                          child: ExamQuestionInput(
                            question: section.questions[i],
                            number: startNumber + i + 1,
                            draft: widget.answers[section.questions[i].id] ??
                                const ExamAnswerDraft(),
                            onChanged: widget.onUpdateAnswer,
                          ),
                        ),
                    ],
                  ),
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
          _metaPill(Icons.help_outline, '${widget.paper.totalQuestions} Questions'),
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
                    onPressed: () => _confirmSubmit(context),
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

  Future<void> _confirmSubmit(BuildContext context) async {
    final unanswered = widget.paper.totalQuestions - _answeredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Text(
          'Submit exam?',
          style: AppTypography.bodyTextXtraLargeSemiBold,
        ),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question(s). Once submitted you '
                  "can't change your answers."
              : "Once submitted you can't change your answers.",
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep working'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.alwaysWhite,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onSubmit();
  }
}
