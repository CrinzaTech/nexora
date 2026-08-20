import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/bloc/exam_cubit.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';

/// Bottom sheet listing all attempts (newest first). Tapping an evaluated
/// attempt reopens its result via the cubit.
Future<void> showExamHistorySheet(
  BuildContext context, {
  required ExamCubit cubit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXL)),
    ),
    builder: (sheetContext) {
      return _ExamHistorySheet(cubit: cubit);
    },
  );
}

class _ExamHistorySheet extends StatelessWidget {
  final ExamCubit cubit;

  const _ExamHistorySheet({required this.cubit});

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
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Row(
                children: [
                  Text(
                    'Attempt history',
                    style: AppTypography.bodyTextXtraLargeSemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AttemptHistoryItem>>(
                future: cubit.fetchHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No attempts yet.',
                        style: AppTypography.bodyTextLargeMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      0,
                      AppSizes.paddingM,
                      AppSizes.paddingL,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.paddingS),
                    itemBuilder: (context, i) => _AttemptTile(
                      item: items[i],
                      onTap: items[i].isEvaluated
                          ? () {
                              Navigator.of(context).pop();
                              cubit.viewResult(items[i].attemptId);
                            }
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttemptTile extends StatelessWidget {
  final AttemptHistoryItem item;
  final VoidCallback? onTap;

  const _AttemptTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final passed = item.hasPassMark ? item.isPassed : null;
    final Color accent = passed == false
        ? AppColors.error
        : passed == true
            ? AppColors.success
            : AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: ExamCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#${item.attemptNo}',
                  style: AppTypography.bodyTextSmallBold.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.score != null && item.maxScore != null
                              ? '${formatMarks(item.score!)} / ${formatMarks(item.maxScore!)}'
                              : item.status,
                          style: AppTypography.bodyTextLargeSemiBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.percentage != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${item.percentage!.toStringAsFixed(1)}%)',
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.mutedTextPrimary,
                            ),
                          ),
                        ],
                        if (item.isCurrent) ...[
                          const SizedBox(width: 6),
                          const ExamChip('Current', color: AppColors.info),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.submittedAt != null
                          ? DateFormat('d MMM yyyy, h:mm a')
                              .format(item.submittedAt!.toLocal())
                          : item.status,
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (passed != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Text(
                    passed ? 'Passed' : 'Failed',
                    style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                      color: accent,
                    ),
                  ),
                ),
              if (onTap != null)
                Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right, color: AppColors.grey300),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
