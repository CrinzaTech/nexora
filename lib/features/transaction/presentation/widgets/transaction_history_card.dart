import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/transaction/data/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Single transaction row — TXN id pill + status badge on top, course
/// name + buyer below, payment method • date footer.
class TransactionHistoryCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionHistoryCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // final txnLabel = transaction.transactionId != null
    //     ? '${transaction.transactionId}'
    //     : '';
    final dateLabel = transaction.createdAt != null
        ? DateFormat('d MMM yyyy').format(transaction.createdAt!)
        : '-';
    final method = transaction.paymentMethod ?? '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        margin: Screen.getMargin(horizontal: 20),
        padding: Screen.getPadding(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          boxShadow: [
            BoxShadow(
              color: AppColors.white.withValues(alpha: 0.9),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: Screen.getPadding(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      transaction.razorpayOrderId?.replaceFirst('order_', '') ??
                          '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.primary,
                        fontSize: Screen.getFontSize(12),
                      ),
                    ),
                  ),
                ),
                _StatusBadge(status: transaction.status),
              ],
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              transaction.courseName ?? 'Course',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextLargeMedium,
            ),
            if (transaction.userName != null &&
                transaction.userName!.isNotEmpty) ...[
              SizedBox(height: Screen.getVerticalSize(2)),
              Text(
                transaction.userName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
            SizedBox(height: Screen.getVerticalSize(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${Utils.toTitleCase(method)} • $dateLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyTextSmallMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour-coded status pill (success/error/warning/info/neutral).
/// Private to this file — only the card uses it.
class _StatusBadge extends StatelessWidget {
  final TransactionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) tone;
    switch (status) {
      case TransactionStatus.completed:
        tone = (bg: AppColors.successBackground, fg: AppColors.successDark);
        break;
      case TransactionStatus.failed:
        tone = (
          bg: AppColors.error.withValues(alpha: 0.12),
          fg: AppColors.error,
        );
        break;
      case TransactionStatus.pending:
        tone = (
          bg: AppColors.warning.withValues(alpha: 0.15),
          fg: AppColors.warningDark,
        );
        break;
      case TransactionStatus.refunded:
        tone = (
          bg: AppColors.info.withValues(alpha: 0.12),
          fg: AppColors.infoDark,
        );
        break;
      case TransactionStatus.unknown:
        tone = (bg: AppColors.grey100, fg: AppColors.mutedTextPrimary);
        break;
    }
    return Container(
      padding: Screen.getPadding(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        status.label,
        style: AppTypography.bodyTextSmallMedium.copyWith(color: tone.fg),
      ),
    );
  }
}
