import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';

/// Full result screen: score ring, tally tiles, and per-question review.
/// Handles the "results held" state when [ExamResultResponse.resultsVisible]
/// is false.
class ExamResultView extends StatelessWidget {
  final ExamResultResponse result;
  final VoidCallback onReattempt;
  final VoidCallback onOpenHistory;

  const ExamResultView({
    super.key,
    required this.result,
    required this.onReattempt,
    required this.onOpenHistory,
  });

  /// Sum of per-question time (competitive mode only; normal mode reports
  /// null per question, so this stays 0). Walks comprehension children too.
  int get _totalTimeSeconds {
    int walk(ExamResultQuestion q) {
      final self = q.timeTakenSeconds ?? 0;
      final kids = q.children.fold<int>(0, (sum, c) => sum + walk(c));
      return self + kids;
    }

    return result.sections
        .expand((s) => s.questions)
        .fold<int>(0, (sum, q) => sum + walk(q));
  }

  @override
  Widget build(BuildContext context) {
    if (!result.resultsVisible) return _held();

    var runningNumber = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingXL,
      ),
      children: [
        _scoreCard(),
        const SizedBox(height: AppSizes.paddingM),
        _tallyRow(),
        const SizedBox(height: AppSizes.paddingS),
        for (final section in result.sections) ...[
          const SizedBox(height: AppSizes.paddingS),
          ExamSectionHeader(name: section.name),
          for (final q in section.questions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
              child: ResultQuestionCard(question: q, number: '${++runningNumber}'),
            ),
        ],
        const SizedBox(height: AppSizes.paddingS),
        _actions(),
      ],
    );
  }

  // ── Held (results not visible) ─────────────────────────────────────────

  Widget _held() {
    final availableAt = result.resultsAvailableAt;
    final scheduled = result.resultReleaseMode == 'scheduled' &&
        availableAt != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock, size: 56, color: AppColors.primary),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'Submitted successfully',
              style: AppTypography.h3SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              scheduled
                  ? 'Your results will be available on '
                      '${DateFormat('d MMM yyyy, h:mm a').format(availableAt.toLocal())}.'
                  : 'Your results are not available to view.',
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.hasAttemptsLeft) ...[
              const SizedBox(height: AppSizes.paddingL),
              _reattemptButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Score card ─────────────────────────────────────────────────────────

  Widget _scoreCard() {
    final percentage = result.percentage ?? 0;
    final passed = result.isPassed;
    final Color accent = passed == false
        ? AppColors.error
        : passed == true
            ? AppColors.success
            : AppColors.primary;
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.examTitle,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          Row(
            children: [
              _scoreRing(percentage, accent),
              const SizedBox(width: AppSizes.paddingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatMarks(result.score ?? 0),
                          style: AppTypography.h2Bold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/ ${formatMarks(result.maxScore ?? 0)}',
                          style: AppTypography.bodyTextLargeMedium.copyWith(
                            color: AppColors.mutedTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Total score',
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                    if (_totalTimeSeconds > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: AppColors.mutedTextPrimary),
                          const SizedBox(width: 4),
                          Text(
                            'Time taken: ${formatDurationSeconds(_totalTimeSeconds)}',
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.mutedTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (passed != null) ...[
                      const SizedBox(height: AppSizes.paddingS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusCircle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              passed ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              passed ? 'Passed' : 'Failed',
                              style:
                                  AppTypography.bodyTextSemiBold.copyWith(
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreRing(double percentage, Color accent) {
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _RingPainter(
          percent: (percentage / 100).clamp(0, 1).toDouble(),
          color: accent,
          track: AppColors.grey100,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 2)}%',
                style: AppTypography.bodyTextLargeBold.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tallyRow() {
    return Row(
      children: [
        Expanded(
          child: _tile('${result.correctCount ?? 0}', 'CORRECT',
              AppColors.success),
        ),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(
          child: _tile('${result.wrongCount ?? 0}', 'WRONG', AppColors.error),
        ),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(
          child: _tile('${result.skippedCount ?? 0}', 'SKIPPED',
              AppColors.grey400),
        ),
      ],
    );
  }

  Widget _tile(String value, String label, Color color) {
    return ExamCard(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.h3Bold.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
              color: AppColors.mutedTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Column(
      children: [
        if (result.hasAttemptsLeft) _reattemptButton(),
        const SizedBox(height: AppSizes.paddingS),
        TextButton.icon(
          onPressed: onOpenHistory,
          icon: const Icon(Icons.history, size: 18),
          label: const Text('View all attempts'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _reattemptButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onReattempt,
        icon: const Icon(Icons.refresh),
        label: Text(
          'Reattempt Exam',
          style: AppTypography.bodyTextLargeSemiBold.copyWith(
            color: AppColors.alwaysWhite,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.alwaysWhite,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
        ),
      ),
    );
  }
}

/// One question in the result review (recursive for comprehension).
class ResultQuestionCard extends StatelessWidget {
  final ExamResultQuestion question;
  final String number;

  /// Nested child cards use a lighter, borderless look.
  final bool nested;

  const ResultQuestionCard({
    super.key,
    required this.question,
    required this.number,
    this.nested = false,
  });

  ExamStatusKind get _status {
    if (question.isSkipped) return ExamStatusKind.skipped;
    if (question.isPartial) return ExamStatusKind.partial;
    if (question.isCorrect == true) return ExamStatusKind.correct;
    return ExamStatusKind.wrong;
  }

  double get _totalPositive => question.isComprehension
      ? question.children.fold<double>(0, (s, c) => s + c.positiveMarks)
      : question.positiveMarks;

  Color get _accent {
    switch (_status) {
      case ExamStatusKind.correct:
        return AppColors.success;
      case ExamStatusKind.wrong:
        return AppColors.error;
      case ExamStatusKind.partial:
        return AppColors.warning;
      case ExamStatusKind.skipped:
        return AppColors.grey300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: AppTypography.bodyTextSmallBold.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            ExamStatusPill(_status),
            if (question.timeTakenSeconds != null) ...[
              const SizedBox(width: 8),
              _timeChip(question.timeTakenSeconds!),
            ],
            const Spacer(),
            Text(
              '${formatMarks(question.marksAwarded)} / ${formatMarks(_totalPositive)}',
              style: AppTypography.bodyTextSmallBold.copyWith(
                color: _accent,
              ),
            ),
          ],
        ),
        // `match_the_column` carries no questionText — skip the block so
        // the rows sit directly under the status row.
        if (question.questionText.trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingS),
          ExamHtmlText(question.questionText),
        ],
        const SizedBox(height: AppSizes.paddingM),
        _body(),
        if ((question.solutionText ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingS),
          _explanation(),
        ],
      ],
    );

    if (nested) {
      return Container(
        margin: const EdgeInsets.only(top: AppSizes.paddingS),
        padding: const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border(left: BorderSide(color: _accent, width: 3)),
        ),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.dividerLight),
        // Accent stripe on the left edge.
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: _accent, width: 3)),
        ),
        padding: const EdgeInsets.only(left: AppSizes.paddingS),
        child: content,
      ),
    );
  }

  Widget _body() {
    switch (question.questionType) {
      case ExamQuestionType.multipleChoice:
      case ExamQuestionType.multipleSelect:
        return _options();
      case ExamQuestionType.trueFalse:
        return _boolReview();
      case ExamQuestionType.integer:
        return _integerReview();
      case ExamQuestionType.fillUps:
        return _blanksReview();
      case ExamQuestionType.matchTheColumn:
        return _matchReview();
      case ExamQuestionType.comprehension:
        return Column(
          children: [
            for (var i = 0; i < question.children.length; i++)
              ResultQuestionCard(
                question: question.children[i],
                number: '$number.${i + 1}',
                nested: true,
              ),
          ],
        );
      case ExamQuestionType.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _options() {
    return Column(
      children: [
        for (var i = 0; i < question.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ResultOptionTile(
            letter: String.fromCharCode(65 + i),
            option: question.options[i],
          ),
        ],
      ],
    );
  }

  Widget _boolReview() {
    return _yourVsCorrect(
      your: question.studentBoolean == null
          ? 'Skipped'
          : (question.studentBoolean! ? 'True' : 'False'),
      correct: question.correctBoolean == null
          ? '-'
          : (question.correctBoolean! ? 'True' : 'False'),
      isCorrect: question.isCorrect == true,
      skipped: question.studentBoolean == null,
    );
  }

  Widget _integerReview() {
    return _yourVsCorrect(
      your: question.studentInteger?.toString() ?? 'Skipped',
      correct: question.correctInteger?.toString() ?? '-',
      isCorrect: question.isCorrect == true,
      skipped: question.studentInteger == null,
    );
  }

  Widget _yourVsCorrect({
    required String your,
    required String correct,
    required bool isCorrect,
    required bool skipped,
  }) {
    final yourColor = skipped
        ? AppColors.grey400
        : (isCorrect ? AppColors.success : AppColors.error);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _pill('Your answer: $your', yourColor, yourColor.withValues(alpha: 0.1)),
        _pill('Correct: $correct', AppColors.success,
            AppColors.grey50, textOnly: true),
      ],
    );
  }

  Widget _pill(String text, Color color, Color bg, {bool textOnly = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: textOnly ? Border.all(color: AppColors.dividerLight) : null,
      ),
      child: Text(
        text,
        style: AppTypography.bodyTextSmallSemiBold.copyWith(
          color: textOnly ? AppColors.textPrimary : color,
        ),
      ),
    );
  }

  Widget _blanksReview() {
    return Column(
      children: [
        for (final b in question.blanks) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    'Blank ${b.index}',
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ),
                _pill(
                  (b.studentText ?? '').trim().isEmpty
                      ? 'skipped'
                      : b.studentText!,
                  b.isCorrect == true ? AppColors.success : AppColors.error,
                  (b.isCorrect == true ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                ),
                const SizedBox(width: 8),
                if ((b.acceptedText ?? '').isNotEmpty)
                  Expanded(
                    child: Text(
                      'accepted: ${b.acceptedText}',
                      style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// One line per Column A PROMPT — prompt → their answer → the correct
  /// one. Column B isn't returned in the result and isn't needed here.
  Widget _matchReview() {
    final rows = question.matchRows;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _matchRowTile(rows[i]),
        ],
      ],
    );
  }

  Widget _matchRowTile(ExamResultMatchRow row) {
    // studentRightText is null only for a genuinely blank row; a wrong
    // pick (a distractor included) keeps the text the student chose.
    final unanswered = row.isUnanswered;
    final Color color = unanswered
        ? AppColors.grey400
        : (row.isCorrect ? AppColors.success : AppColors.error);
    final IconData icon = unanswered
        ? Icons.remove_circle_outline
        : (row.isCorrect ? Icons.check_circle : Icons.cancel);

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.index}. ${row.leftText}',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _pill(
                      unanswered
                          ? 'Not answered'
                          : 'Your answer: ${row.studentRightText}',
                      color,
                      color.withValues(alpha: 0.12),
                    ),
                    // The correct answer only needs spelling out when
                    // theirs wasn't it.
                    if (!row.isCorrect)
                      _pill(
                        'Correct: ${row.correctRightText ?? '-'}',
                        AppColors.success,
                        AppColors.white,
                        textOnly: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small "time spent on this question" chip. Only present for
  /// competitive-mode results (normal mode returns null).
  Widget _timeChip(int seconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: AppColors.info),
          const SizedBox(width: 4),
          Text(
            formatDurationSeconds(seconds),
            style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _explanation() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explanation',
            style: AppTypography.bodyTextSmallSemiBold.copyWith(
              color: AppColors.infoDark,
            ),
          ),
          const SizedBox(height: 4),
          ExamHtmlText(
            question.solutionText!,
            baseStyle: AppTypography.bodyTextSmallMedium,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// A single reviewed option, colour-coded by (isCorrect, isSelected).
class _ResultOptionTile extends StatelessWidget {
  final String letter;
  final ExamResultOption option;

  const _ResultOptionTile({required this.letter, required this.option});

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.dividerLight;
    Color bg = AppColors.white;
    String? tag;
    Color tagColor = AppColors.mutedTextPrimary;
    IconData? icon;

    if (option.isCorrect && option.isSelected) {
      // Correct answer the student picked → green.
      border = AppColors.success;
      bg = AppColors.success.withValues(alpha: 0.08);
      tag = 'your choice · correct';
      tagColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (option.isCorrect && !option.isSelected) {
      // A correct answer the student did NOT pick (missed) → orange, so a
      // partial multiple-select clearly shows what was left out.
      border = AppColors.warning.withValues(alpha: 0.6);
      bg = AppColors.warning.withValues(alpha: 0.08);
      tag = 'correct answer · missed';
      tagColor = AppColors.warningDark;
      icon = Icons.error_outline;
    } else if (!option.isCorrect && option.isSelected) {
      // A wrong option the student picked → red.
      border = AppColors.error;
      bg = AppColors.error.withValues(alpha: 0.06);
      tag = 'your choice · wrong';
      tagColor = AppColors.error;
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.radio_button_unchecked,
            size: 18,
            color: icon != null ? tagColor : AppColors.grey200,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExamHtmlText(
                  option.text,
                  baseStyle: AppTypography.bodyTextMedium,
                  color: AppColors.textPrimary,
                ),
                if (tag != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tag,
                      style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                        color: tagColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular score ring.
class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color track;

  _RingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}
