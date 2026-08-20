import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';

/// A small rounded label chip (e.g. "Single Selection", "Medium",
/// "2.00 Marks"). Neutral by default; pass [color] to tint.
class ExamChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  const ExamChip(
    this.label, {
    super.key,
    this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.grey400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? AppColors.alwaysWhite : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
              color: filled ? AppColors.alwaysWhite : c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill used on result questions: Correct / Wrong / Partial / Skipped.
enum ExamStatusKind { correct, wrong, partial, skipped }

class ExamStatusPill extends StatelessWidget {
  final ExamStatusKind kind;

  const ExamStatusPill(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (kind) {
      case ExamStatusKind.correct:
        color = AppColors.success;
        label = 'Correct';
      case ExamStatusKind.wrong:
        color = AppColors.error;
        label = 'Wrong';
      case ExamStatusKind.partial:
        color = AppColors.warning;
        label = 'Partially correct';
      case ExamStatusKind.skipped:
        color = AppColors.grey300;
        label = 'Skipped';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        label,
        style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(color: color),
      ),
    );
  }
}

/// A section band header ("SECTION A"), with a leading accent bar.
class ExamSectionHeader extends StatelessWidget {
  final String name;
  final String? trailing;

  const ExamSectionHeader({super.key, required this.name, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingS),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// White rounded card wrapper used for each question block.
class ExamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? background;

  const ExamCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: background ?? AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: borderColor ?? AppColors.dividerLight,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Eye-catching, readable callout for section / exam instructions so a
/// student can't skim past them as plain text. Amber tinted, with a pinned
/// "INSTRUCTIONS" eyebrow and the HTML body in full-contrast text.
class ExamInstructionCallout extends StatelessWidget {
  final String html;
  final String label;

  const ExamInstructionCallout(
    this.html, {
    super.key,
    this.label = 'Instructions',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.push_pin_outlined,
                size: 16, color: AppColors.warningDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.bodyTextXtraSmallBold.copyWith(
                    color: AppColors.warningDark,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                ExamHtmlText(
                  html,
                  baseStyle: AppTypography.bodyTextMedium,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Difficulty → tint used on the difficulty chip.
Color difficultyColor(String? difficulty) {
  switch (difficulty?.trim().toLowerCase()) {
    case 'easy':
      return AppColors.success;
    case 'medium':
      return AppColors.warning;
    case 'hard':
      return AppColors.error;
    default:
      return AppColors.grey400;
  }
}

/// Format marks without trailing zeros noise (2.00 → "2", 2.50 → "2.5").
String formatMarks(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Format a duration in seconds as a short human label
/// (45 → "45s", 90 → "1m 30s", 3600 → "1h 0m").
String formatDurationSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}
