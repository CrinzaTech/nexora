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

// ── Dialogs ──────────────────────────────────────────────────────────────

/// The exam's confirm / warning prompts, so they read as one family: a
/// tinted icon medallion, centred copy, and full-width stacked actions.
class ExamDialogShell extends StatelessWidget {
  final IconData icon;

  /// Tints the medallion. Also the natural colour for a destructive action.
  final Color accent;

  final String title;
  final String message;

  /// Optional block between the message and the actions.
  final Widget? extra;

  /// Rendered full width, in order, primary first.
  final List<Widget> actions;

  const ExamDialogShell({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    this.extra,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingXL,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingL,
            AppSizes.paddingL,
            AppSizes.paddingL,
            AppSizes.paddingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.08),
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon, size: 26, color: accent),
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextXtraLargeSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: AppSizes.paddingM),
                extra!,
              ],
              const SizedBox(height: AppSizes.paddingL),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: actions[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled pill action for [ExamDialogShell].
class ExamDialogAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback onPressed;

  const ExamDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final background = color ?? AppColors.primary;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: AppColors.alwaysWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: AppColors.alwaysWhite),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.alwaysWhite,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet secondary action for [ExamDialogShell].
class ExamDialogGhostAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ExamDialogGhostAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
