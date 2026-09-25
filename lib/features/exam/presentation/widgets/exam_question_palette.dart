import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';

/// Where a question stands, as painted in the palette grid.
enum ExamPaletteStatus {
  /// Nothing entered yet.
  unanswered,

  /// A comprehension block with some — but not all — children answered.
  partial,

  /// Answered. Pre-submit only; grading replaces this.
  answered,

  /// Graded correct (or fully credited).
  correct,

  /// Graded wrong, including partial credit.
  wrong,

  /// Graded but left blank.
  skipped,

  /// Quiz/competitive progress: the question on screen right now.
  current,

  /// Quiz/competitive progress: the server hasn't served it yet. Distinct
  /// from [unanswered], which the student could still go and answer.
  upcoming,
}

/// One cell of the palette: a question's display number and its state.
class ExamPaletteEntry {
  /// 1-based number, matching the badge on the question card.
  final int number;

  final ExamPaletteStatus status;

  /// Pinned questions take over the cell's colour, so the answered state
  /// moves to a dot in the corner rather than being lost.
  final bool pinned;

  /// Whether tapping this cell does anything. False for the questions a
  /// quiz hasn't served yet — there is nothing to show, and a cell that
  /// looks tappable but isn't is worse than one that plainly isn't.
  final bool selectable;

  const ExamPaletteEntry({
    required this.number,
    required this.status,
    this.pinned = false,
    this.selectable = true,
  });
}

/// Opens the question grid. Resolves to the 0-based index of the question
/// the student tapped, or null if they dismissed the sheet.
///
/// [jumpable] false marks the grid as a *progress* view rather than a
/// navigable paper: the quiz and competitive flows are paced by the
/// server, so tapping a cell reopens a question the client already saw
/// instead of moving the paper to it. Which cells respond is decided per
/// entry by [ExamPaletteEntry.selectable]; this flag only picks the
/// wording.
Future<int?> showExamQuestionPalette(
  BuildContext context, {
  required List<ExamPaletteEntry> entries,
  required bool reviewMode,
  bool jumpable = true,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.overlayMedium,
    isScrollControlled: true,
    builder: (ctx) => _PaletteSheet(
      entries: entries,
      reviewMode: reviewMode,
      jumpable: jumpable,
    ),
  );
}

class _PaletteSheet extends StatelessWidget {
  final List<ExamPaletteEntry> entries;
  final bool reviewMode;
  final bool jumpable;

  const _PaletteSheet({
    required this.entries,
    required this.reviewMode,
    this.jumpable = true,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <ExamPaletteStatus, int>{};
    var pinned = 0;
    for (final e in entries) {
      counts[e.status] = (counts[e.status] ?? 0) + 1;
      if (e.pinned) pinned++;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabber(),
            _header(),
            const SizedBox(height: AppSizes.paddingS),
            _Legend(
              reviewMode: reviewMode,
              jumpable: jumpable,
              counts: counts,
              pinned: pinned,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
              ),
              child: Divider(height: 1, color: AppColors.dividerLight),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.paddingM,
                  AppSizes.paddingM,
                  AppSizes.paddingM,
                  AppSizes.paddingS,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: entries.length,
                itemBuilder: (_, i) => ExamPaletteCell(
                  entry: entries[i],
                  onTap: entries[i].selectable
                      ? () => Navigator.of(context).pop(i)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingM,
                AppSizes.paddingS,
                AppSizes.paddingM,
                AppSizes.paddingS,
              ),
              child: Row(
                children: [
                  Icon(
                    jumpable ? Icons.touch_app_outlined : Icons.history_rounded,
                    size: 15,
                    color: AppColors.mutedTextPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      jumpable
                          ? 'Tap any number to jump straight to that question.'
                          : 'Tap a question you have already seen to look back '
                                'at it. One you skipped can still be answered for '
                                'free; a wrong answer can be changed for a point.',
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        AppSizes.paddingS,
        AppSizes.paddingM,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              reviewMode
                  ? Icons.fact_check_outlined
                  : (jumpable
                        ? Icons.grid_view_rounded
                        : Icons.timeline_rounded),
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewMode
                      ? 'Question review'
                      : (jumpable ? 'Question overview' : 'Your progress'),
                  style: AppTypography.bodyTextXtraLargeSemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${entries.length} question${entries.length == 1 ? '' : 's'}',
                  style: AppTypography.bodyTextSmallMedium.copyWith(
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
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.grey300,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final bool reviewMode;
  final bool jumpable;
  final Map<ExamPaletteStatus, int> counts;
  final int pinned;

  const _Legend({
    required this.reviewMode,
    required this.jumpable,
    required this.counts,
    required this.pinned,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    void add(ExamPaletteStatus status, String label) {
      final n = counts[status] ?? 0;
      if (n == 0) return;
      items.add(_LegendPill(color: _accentFor(status), label: label, count: n));
    }

    void addPinned() {
      if (pinned == 0) return;
      items.add(
        _LegendPill(color: AppColors.warning, label: 'Pinned', count: pinned),
      );
    }

    if (reviewMode) {
      add(ExamPaletteStatus.correct, 'Correct');
      add(ExamPaletteStatus.wrong, 'Wrong');
      add(ExamPaletteStatus.skipped, 'Skipped');
      // Only a practice run has these; a finished paper never does, and a
      // zero count draws no pill.
      add(ExamPaletteStatus.current, 'On this one');
      add(ExamPaletteStatus.upcoming, 'Not seen');
      // Pins made during the exam are the student's own "come back to
      // this" marks, and they are most useful afterwards — this is the
      // screen where they finally get to act on them.
      addPinned();
    } else if (!jumpable) {
      add(ExamPaletteStatus.answered, 'Answered');
      add(ExamPaletteStatus.skipped, 'Skipped');
      add(ExamPaletteStatus.current, 'On this one');
      add(ExamPaletteStatus.upcoming, 'To come');
      addPinned();
    } else {
      add(ExamPaletteStatus.answered, 'Attempted');
      add(ExamPaletteStatus.partial, 'Partly done');
      add(ExamPaletteStatus.unanswered, 'Not attempted');
      addPinned();
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        0,
        AppSizes.paddingM,
        AppSizes.paddingS,
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendPill({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodyTextSmallMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: AppTypography.bodyTextSmallBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Cell ─────────────────────────────────────────────────────────────────

/// The colour that identifies a status — the legend dot, and the fill for
/// the statuses that are painted solid.
Color _accentFor(ExamPaletteStatus status) {
  switch (status) {
    case ExamPaletteStatus.answered:
    case ExamPaletteStatus.correct:
      return AppColors.success;
    case ExamPaletteStatus.wrong:
      return AppColors.error;
    case ExamPaletteStatus.partial:
      return AppColors.info;
    case ExamPaletteStatus.unanswered:
    case ExamPaletteStatus.skipped:
    case ExamPaletteStatus.upcoming:
      return AppColors.grey400;
    case ExamPaletteStatus.current:
      return AppColors.primary;
  }
}

/// Solid-filled statuses carry white numerals and a tinted drop shadow; the
/// quiet ones stay outlined so the grid doesn't read as a wall of colour.
bool _isSolid(ExamPaletteStatus status) {
  switch (status) {
    case ExamPaletteStatus.answered:
    case ExamPaletteStatus.correct:
    case ExamPaletteStatus.wrong:
    case ExamPaletteStatus.current:
    // Solid grey, so a question the student passed over reads as settled
    // but empty — not mistaken for answered green or a still-to-come cell.
    case ExamPaletteStatus.skipped:
      return true;
    case ExamPaletteStatus.partial:
    case ExamPaletteStatus.unanswered:
    case ExamPaletteStatus.upcoming:
      return false;
  }
}

/// A single numbered square. Pinned wins the fill colour; the dot underneath
/// the numeral then carries whether the question was actually answered.
class ExamPaletteCell extends StatelessWidget {
  final ExamPaletteEntry entry;

  /// Null in the read-only progress view, where there is nothing to jump
  /// to — the cell then renders identically but doesn't respond.
  final VoidCallback? onTap;

  const ExamPaletteCell({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pinned = entry.pinned;
    final accent = pinned ? AppColors.warning : _accentFor(entry.status);
    final solid = pinned || _isSolid(entry.status);

    final fill = solid
        ? accent
        : (entry.status == ExamPaletteStatus.partial
              ? accent.withValues(alpha: 0.10)
              : AppColors.grey50);
    final foreground = solid ? AppColors.alwaysWhite : AppColors.textPrimary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: solid
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: solid
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '${entry.number}',
                    style: AppTypography.bodyTextBold.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                if (pinned)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.push_pin,
                      size: 12,
                      color: AppColors.alwaysWhite.withValues(alpha: 0.9),
                    ),
                  ),
                // The pin colour hides the answered state, so a green tick
                // brings it back in the same colour the grid uses for
                // "attempted". It sits on a white disc because green on
                // amber is otherwise too low-contrast to read. Nothing is
                // drawn while unanswered — a faint marker reads as a smudge.
                if (pinned && entry.status == ExamPaletteStatus.answered)
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.alwaysWhite,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating stats button ────────────────────────────────────────────────

/// The draggable button that opens the palette. The pin count rides on it as
/// a circular badge, so a parked question is visible without opening
/// anything.
class ExamStatsFab extends StatelessWidget {
  final int pinnedCount;
  final VoidCallback onTap;

  const ExamStatsFab({
    super.key,
    required this.pinnedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(AppColors.primary, AppColors.black, 0.24)!;
    return SizedBox(
      // Room for the badge to overhang without being clipped by the Stack.
      width: 68,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, deep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.alwaysWhite,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (pinnedCount > 0)
            Positioned(top: 0, right: 0, child: _PinBadge(count: pinnedCount)),
        ],
      ),
    );
  }
}

/// Fixed-diameter circle — the count is capped at "9+" so the badge never
/// has to stretch into a lozenge.
class _PinBadge extends StatelessWidget {
  final int count;

  const _PinBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.warning,
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: AppTypography.bodyTextXtraSmallBold.copyWith(
          color: AppColors.alwaysWhite,
          height: 1,
        ),
      ),
    );
  }
}

// ── Pinned-questions gate (shown when submitting with pins left) ─────────

/// What the student chose on the "you still have pinned questions" dialog.
class ExamPinnedGateOutcome {
  /// Clear the pins and carry on to the submit confirmation.
  final bool proceed;

  /// 0-based index of a pinned question they tapped to revisit instead.
  final int? jumpToIndex;

  const ExamPinnedGateOutcome({this.proceed = false, this.jumpToIndex});
}

/// Shown when Submit is pressed with pins outstanding. Returns null when the
/// student backs out and stays on the paper.
Future<ExamPinnedGateOutcome?> showExamPinnedGate(
  BuildContext context, {
  required List<ExamPaletteEntry> pinnedEntries,
  required List<int> pinnedIndexes,
}) {
  final n = pinnedEntries.length;
  return showDialog<ExamPinnedGateOutcome>(
    context: context,
    barrierColor: AppColors.overlayMedium,
    builder: (ctx) => ExamDialogShell(
      icon: Icons.push_pin_rounded,
      accent: AppColors.warning,
      title: n == 1 ? '1 pinned question left' : '$n pinned questions left',
      message: n == 1
          ? 'You pinned this one to come back to. Tap it to revisit, or '
                'proceed to submit anyway.'
          : 'You pinned these to come back to. Tap one to revisit, or '
                'proceed to submit anyway.',
      extra: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < pinnedEntries.length; i++)
            SizedBox(
              width: 48,
              height: 48,
              child: ExamPaletteCell(
                entry: pinnedEntries[i],
                onTap: () => Navigator.of(
                  ctx,
                ).pop(ExamPinnedGateOutcome(jumpToIndex: pinnedIndexes[i])),
              ),
            ),
        ],
      ),
      actions: [
        ExamDialogAction(
          label: 'Proceed to submit',
          icon: Icons.arrow_forward_rounded,
          onPressed: () =>
              Navigator.of(ctx).pop(const ExamPinnedGateOutcome(proceed: true)),
        ),
        ExamDialogGhostAction(
          label: 'Keep working',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}
