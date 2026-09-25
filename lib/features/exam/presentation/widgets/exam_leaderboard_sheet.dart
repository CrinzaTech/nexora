import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/bloc/exam_cubit.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';

/// Bar colours. One colour for every other student and a second for the
/// viewer — bars are deliberately NOT shaded by rank, because a gradient
/// would imply the colour carries meaning the rank number and bar length
/// already carry. Validated as a pair for colour-vision separation.
const Color _kBar = Color(0xFF00938A);
const Color _kBarMe = Color(0xFFB4530F);

/// Bottom sheet showing the rankings for the exam *placement* the student is
/// standing in: the top students by name, plus where the viewer stands when
/// they didn't make the cut.
Future<void> showExamLeaderboardSheet(
  BuildContext context, {
  required ExamCubit cubit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXL),
      ),
    ),
    builder: (sheetContext) => _ExamLeaderboardSheet(cubit: cubit),
  );
}

class _ExamLeaderboardSheet extends StatefulWidget {
  final ExamCubit cubit;

  const _ExamLeaderboardSheet({required this.cubit});

  @override
  State<_ExamLeaderboardSheet> createState() => _ExamLeaderboardSheetState();
}

class _ExamLeaderboardSheetState extends State<_ExamLeaderboardSheet> {
  /// Held rather than called inline in the builder, so a rebuild (from the
  /// draggable sheet resizing, say) doesn't re-fire the request. Replaced
  /// only by Retry.
  late Future<ExamLeaderboard?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cubit.fetchLeaderboard();
  }

  void _retry() {
    setState(() => _future = widget.cubit.fetchLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: FutureBuilder<ExamLeaderboard?>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        _header(),
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }
                  final board = snapshot.data;
                  // Null is a failure, never an empty board — showing an
                  // empty board here would read as "nobody has sat it".
                  if (board == null) {
                    return Column(
                      children: [
                        _header(),
                        Expanded(
                          child: _Placeholder(
                            icon: Icons.wifi_off_rounded,
                            title: 'Couldn’t load rankings',
                            message: 'Check your connection and try again.',
                            onRetry: _retry,
                          ),
                        ),
                      ],
                    );
                  }
                  return _board(board, scrollController);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  /// [board] is null while loading / on failure, when there is no pool size
  /// to report yet.
  Widget _header([ExamLeaderboard? board]) {
    // Worth saying out loud: the same exam placed in another course has its
    // own separate board, and students will otherwise compare notes across
    // courses and think the ranking is broken.
    final subtitle = board == null
        ? 'Ranked within this course'
        : board.totalRanked > 0
        ? '${board.totalRanked} ranked · within this course'
        : 'Ranked within this course';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingM,
        AppSizes.paddingS,
      ),
      child: Row(
        children: [
          Icon(Icons.leaderboard_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rankings',
                  style: AppTypography.bodyTextXtraLargeSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Board ──────────────────────────────────────────────────────────────

  Widget _board(ExamLeaderboard board, ScrollController scrollController) {
    // Results withheld by the educator. `top` is empty and `me` null BY
    // DESIGN here — this is not the same as nobody having sat the exam, and
    // telling a class their results are withheld when the exam simply hasn't
    // been taken is a support ticket.
    if (!board.resultsVisible) {
      final at = board.resultsAvailableAt;
      return Column(
        children: [
          _header(board),
          Expanded(
            child: _Placeholder(
              icon: Icons.lock_clock_rounded,
              title: at != null
                  ? 'Rankings open ${DateFormat('d MMM, h:mm a').format(at.toLocal())}'
                  : 'Rankings are not published',
              message: at != null
                  ? 'Come back once results are released for this exam.'
                  : 'The educator has not published rankings for this exam.',
            ),
          ),
        ],
      );
    }

    // Nobody has finished yet — distinct from the withheld case above.
    if (board.isEmptyBoard) {
      return Column(
        children: [
          _header(board),
          const Expanded(
            child: _Placeholder(
              icon: Icons.emoji_events_outlined,
              title: 'No rankings yet',
              message: 'Be the first to complete this exam.',
            ),
          ),
        ],
      );
    }

    final me = board.me;
    // `me` is populated even when the student is in the top, so this branch
    // is what stops them being drawn twice — once highlighted in the board
    // and again in the detached row.
    final showDetachedMe = !board.isMeInTop && me != null;

    // Ties at the cut-off mean the board can be longer than `topCount`;
    // the gap is measured from the last rank actually returned.
    final between = showDetachedMe ? me.rank - board.top.last.rank - 1 : 0;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppSizes.paddingL),
      children: [
        _header(board),
        // Driven by top.length, never sliced back to topCount — that would
        // cut students genuinely tied with the ones kept.
        for (final entry in board.top)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              0,
              AppSizes.paddingM,
              AppSizes.paddingS,
            ),
            child: _LeaderboardRow(entry: entry),
          ),
        if (showDetachedMe) ...[
          _Separator(between: between),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              0,
              AppSizes.paddingM,
              AppSizes.paddingS,
            ),
            child: _LeaderboardRow(entry: me),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          child: Text(
            // Unranked is not last: a student with no evaluated attempt here
            // gets no rank at all, never 0 and never totalRanked + 1.
            me == null
                ? 'Finish the exam to see your rank.'
                : 'Rank ${me.rank} of ${board.totalRanked} · '
                      'best of ${me.attemptNo} '
                      '${me.attemptNo == 1 ? 'attempt' : 'attempts'}',
            style: AppTypography.bodyTextXtraSmallMedium.copyWith(
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── One student's row ────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = entry.isMe ? _kBarMe : _kBar;
    return ExamCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: 10,
      ),
      borderColor: entry.isMe ? _kBarMe.withValues(alpha: 0.45) : null,
      background: entry.isMe ? _kBarMe.withValues(alpha: 0.05) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ranks are shared on ties (1, 2, 2, 4) and so are neither
              // unique nor contiguous — shown as data, never used as an index.
              SizedBox(
                width: 26,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.end,
                  style: AppTypography.bodyTextSmallBold.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextSmallSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Not decoration: the secondary encoding, so the viewer's row
              // stays identifiable without colour vision.
              if (entry.isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kBarMe,
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Text(
                    'YOU',
                    style: AppTypography.bodyTextXtraSmallBold.copyWith(
                      color: AppColors.alwaysWhite,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                entry.maxScore > 0
                    ? '${formatMarks(entry.score)}/${formatMarks(entry.maxScore)}'
                    : formatMarks(entry.score),
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Full-width track behind the bar, so a zero score still shows
              // a row rather than nothing.
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: entry.scoreFraction,
                    minHeight: 6,
                    backgroundColor: AppColors.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
              // The rank is computed from the effective score, not the marks
              // above it. Where points moved a student, say so on the row —
              // otherwise two identical scores in different positions read
              // as a bug in the board.
              if (entry.rankWasPenalised) ...[
                Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  formatMarks(entry.rankPenalty),
                  style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingS),
              ],
              // Pre-formatted by the server and rendered as sent, so the
              // tie-break reads identically on every platform. Shown on every
              // row so equal scores in a different order never look arbitrary.
              Text(
                entry.timeTaken,
                style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── The break between the board and a detached "you" ─────────────────────

class _Separator extends StatelessWidget {
  final int between;

  const _Separator({required this.between});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        AppSizes.paddingM,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.grey200, height: 1)),
          if (between > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingS,
              ),
              child: Text(
                '$between ${between == 1 ? 'student' : 'students'} between',
                style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ),
          Expanded(child: Divider(color: AppColors.grey200, height: 1)),
        ],
      ),
    );
  }
}

// ── Empty / withheld / failed ────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _Placeholder({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.grey300),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingXS),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.paddingM),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
