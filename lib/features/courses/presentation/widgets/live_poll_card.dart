import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';

/// A poll the educator posted into the chat, rendered in place of the
/// text bubble. Four looks, all driven by the [poll] handed in:
///
/// 1. open, not answered — radio / checkboxes + Submit, with a countdown
///    (timed) or "Results when the host shares them" (manual);
/// 2. open, answered — locked, chosen options highlighted, "Answer
///    submitted", countdown kept;
/// 3. revealed — percentage bars, "N answered", correct options marked
///    when the poll has an answer key, this student's pick highlighted;
/// 4. cancelled — greyed out.
///
/// Selection is local until Submit; everything else re-renders from the
/// cubit's poll map, which is why a reveal or cancel updates the card in
/// place without the chat list knowing.
class LivePollCard extends StatefulWidget {
  final LivePoll poll;

  /// Called with the chosen option ids — exactly one for a single-choice
  /// poll, all ticked ones for multiple.
  final ValueChanged<List<int>> onSubmit;

  /// The timed deadline just passed and no reveal has arrived yet — the
  /// owner may re-fetch the poll. Fired once per card.
  final VoidCallback? onDeadline;

  const LivePollCard({
    super.key,
    required this.poll,
    required this.onSubmit,
    this.onDeadline,
  });

  @override
  State<LivePollCard> createState() => _LivePollCardState();
}

class _LivePollCardState extends State<LivePollCard> {
  final Set<int> _selected = {};
  Timer? _ticker;
  bool _deadlineFired = false;
  bool _submitting = false;

  /// The spinner ends when the poll comes back changed (vote accepted,
  /// reveal, cancel). If nothing comes back — the ack was lost, or the
  /// server refused and only a toast said so — give the button back
  /// rather than spin forever; a second tap on a registered vote just
  /// earns a "you already answered".
  Timer? _submitTimeout;
  static const _submitTimeoutAfter = Duration(seconds: 6);

  LivePoll get poll => widget.poll;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LivePollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A vote acknowledged / reveal / cancel arrived: the local draft is
    // meaningless now and the submit spinner must not outlive it.
    if (oldWidget.poll.status != poll.status ||
        oldWidget.poll.hasAnswered != poll.hasAnswered ||
        oldWidget.poll.resultsVisible != poll.resultsVisible) {
      _submitting = false;
      _submitTimeout?.cancel();
      _submitTimeout = null;
      if (poll.hasAnswered || !poll.isOpen) _selected.clear();
    }
    _syncTicker();
  }

  /// A 1s tick only while there is a countdown to draw.
  void _syncTicker() {
    final wants = poll.isTimed && poll.isOpen && poll.revealAt != null;
    if (wants && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (poll.deadlinePassed && !_deadlineFired) {
          _deadlineFired = true;
          widget.onDeadline?.call();
        }
      });
    } else if (!wants && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _submitTimeout?.cancel();
    super.dispose();
  }

  void _toggle(int optionId) {
    if (!poll.canVote || _submitting) return;
    setState(() {
      if (poll.isMultiple) {
        if (!_selected.remove(optionId)) _selected.add(optionId);
      } else {
        _selected
          ..clear()
          ..add(optionId);
      }
    });
  }

  void _submit() {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    _submitTimeout?.cancel();
    _submitTimeout = Timer(_submitTimeoutAfter, () {
      _submitTimeout = null;
      if (mounted && _submitting) setState(() => _submitting = false);
    });
    widget.onSubmit(_selected.toList());
  }

  String _countdown() {
    final at = poll.revealAt;
    if (at == null) return '';
    final left = at.difference(DateTime.now());
    if (left.isNegative) return 'Results in 0:00';
    final m = left.inMinutes;
    final s = left.inSeconds % 60;
    return 'Results in $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = poll.isCancelled;
    final revealed = poll.isRevealed || poll.resultsVisible;
    final locked = !poll.canVote;
    final tint = cancelled ? AppColors.mutedTextPrimary : AppColors.primary;

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.poll_outlined, size: 16, color: tint),
                const SizedBox(width: 6),
                Text(
                  poll.isMultiple ? 'POLL · PICK ANY' : 'POLL · PICK ONE',
                  style: AppTypography.labelSmall.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              poll.question,
              style: AppTypography.bodyTextSemiBold,
            ),
            const SizedBox(height: 8),
            for (final option in poll.options) ...[
              _OptionRow(
                option: option,
                poll: poll,
                selected: _selected.contains(option.id),
                mine: poll.myOptionIds.contains(option.id),
                revealed: revealed,
                locked: locked,
                onTap: () => _toggle(option.id),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 2),
            _footer(revealed: revealed, cancelled: cancelled),
          ],
        ),
      ),
    );
  }

  Widget _footer({required bool revealed, required bool cancelled}) {
    final muted = AppTypography.labelSmall.copyWith(
      color: AppColors.mutedTextPrimary,
    );
    if (cancelled) {
      return Text('This poll was cancelled', style: muted);
    }
    if (revealed) {
      final n = poll.attempted;
      return Text(
        n == null ? 'Results' : '$n answered',
        style: muted,
      );
    }
    final String status;
    if (poll.hasAnswered) {
      status = 'Answer submitted';
    } else if (poll.deadlinePassed) {
      status = 'Voting has closed';
    } else if (poll.isTimed) {
      status = _countdown();
    } else {
      status = 'Results when the host shares them';
    }
    final hint = poll.hasAnswered && poll.isTimed && !poll.deadlinePassed
        ? ' · ${_countdown()}'
        : '';
    return Row(
      children: [
        Expanded(
          child: Text(
            '$status$hint',
            style: muted.copyWith(
              color: poll.hasAnswered
                  ? AppColors.successDark
                  : AppColors.mutedTextPrimary,
              fontWeight:
                  poll.hasAnswered ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (poll.canVote)
          SizedBox(
            height: 30,
            child: FilledButton(
              onPressed: _selected.isEmpty || _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.alwaysWhite,
                      ),
                    )
                  : Text(
                      'Submit',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.alwaysWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final LivePollOption option;
  final LivePoll poll;
  final bool selected;
  final bool mine;
  final bool revealed;
  final bool locked;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.poll,
    required this.selected,
    required this.mine,
    required this.revealed,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = selected || mine;
    final correct = revealed ? option.isCorrect : null;
    final Color edge;
    if (correct == true) {
      edge = AppColors.successDark;
    } else if (correct == false && mine) {
      edge = AppColors.error;
    } else if (highlighted) {
      edge = AppColors.primary;
    } else {
      edge = AppColors.grey200;
    }

    final total = poll.attempted ?? 0;
    final votes = option.votes ?? 0;
    final share = revealed && total > 0 ? (votes / total).clamp(0.0, 1.0) : 0.0;

    final IconData marker;
    if (correct == true) {
      marker = Icons.check_circle;
    } else if (correct == false && mine) {
      marker = Icons.cancel;
    } else if (poll.isMultiple) {
      marker = highlighted ? Icons.check_box : Icons.check_box_outline_blank;
    } else {
      marker = highlighted
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked;
    }

    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: edge, width: highlighted ? 1.5 : 1),
          color: AppColors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Result bar behind the label once counts are visible.
            if (revealed)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: share,
                  child: ColoredBox(
                    color: (correct == true
                            ? AppColors.successDark
                            : AppColors.primary)
                        .withValues(alpha: 0.14),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(marker, size: 18, color: edge),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.label,
                      style: AppTypography.bodyTextMedium.copyWith(
                        fontWeight:
                            highlighted ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (revealed) ...[
                    const SizedBox(width: 8),
                    Text(
                      total > 0
                          ? '${(share * 100).round()}% · $votes'
                          : '$votes',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mutedTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
