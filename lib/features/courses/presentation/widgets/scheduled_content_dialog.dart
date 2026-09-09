import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Explains why a scheduled node won't open yet.
///
/// Replaces the snackbar that previously carried this message — the copy
/// names a date, a time and the content itself, which a two-line
/// auto-dismissing toast truncated. A dialog holds the full text until
/// the student dismisses it.
///
/// Used for both flavours of "not yet":
///  * a scheduled file/folder ([isLiveClass] `false`) — unlocks at [startAt]
///  * an upcoming live class ([isLiveClass] `true`) — joinable at [startAt]
class ScheduledContentDialog extends StatelessWidget {
  final String nodeName;

  /// Local time (curriculum values are `.toLocal()`-converted at parse).
  final DateTime startAt;

  final bool isLiveClass;

  const ScheduledContentDialog._({
    required this.nodeName,
    required this.startAt,
    required this.isLiveClass,
  });

  static Future<void> show(
    BuildContext context, {
    required String nodeName,
    required DateTime startAt,
    bool isLiveClass = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ScheduledContentDialog._(
        nodeName: nodeName,
        startAt: startAt,
        isLiveClass: isLiveClass,
      ),
    );
  }

  /// "Monday, 8 September 2026" — spelled out, so there is no ambiguity
  /// about which date the student is waiting for.
  String get _dateLabel => DateFormat('EEEE, d MMMM yyyy').format(startAt);

  String get _timeLabel => DateFormat('h:mm a').format(startAt);

  /// "in 2 days 4 hours" / "in 35 minutes" — the practical answer to
  /// "how long do I wait?". Null once the moment has effectively arrived
  /// (the row unlocks itself on the next tick, so no countdown is shown).
  String? get _countdown {
    final remaining = startAt.difference(DateTime.now());
    if (remaining.inMinutes < 1) return null;
    if (remaining.inDays >= 1) {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      final d = '$days ${days == 1 ? 'day' : 'days'}';
      if (hours == 0) return 'in $d';
      return 'in $d ${hours == 1 ? '1 hour' : '$hours hours'}';
    }
    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final h = '$hours ${hours == 1 ? 'hour' : 'hours'}';
      if (minutes == 0) return 'in $h';
      return 'in $h ${minutes == 1 ? '1 minute' : '$minutes minutes'}';
    }
    final minutes = remaining.inMinutes;
    return 'in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: Screen.getPadding(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: Screen.getPadding(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(Screen.getSize(14)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  isLiveClass ? Icons.event_available : Icons.lock_clock,
                  size: Screen.getSize(30),
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(16)),
              Text(
                isLiveClass ? 'Class Not Started Yet' : 'Scheduled Content',
                textAlign: TextAlign.center,
                style: AppTypography.h5SemiBold.copyWith(
                  fontSize: Screen.getFontSize(18),
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(6)),
              Text(
                nodeName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextMedium.copyWith(
                  fontSize: Screen.getFontSize(13),
                  color: AppColors.mutedTextPrimary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(18)),
              // The schedule itself, boxed so the date and time read as
              // the answer to the question the student just asked.
              Container(
                width: double.infinity,
                padding: Screen.getPadding(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isLiveClass ? 'Starts on' : 'Unlocks on',
                      style: AppTypography.bodyTextMedium.copyWith(
                        fontSize: Screen.getFontSize(11),
                        color: AppColors.mutedTextPrimary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(6)),
                    Text(
                      _dateLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        fontSize: Screen.getFontSize(14),
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(2)),
                    Text(
                      'at $_timeLabel',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        fontSize: Screen.getFontSize(14),
                        color: AppColors.primary,
                      ),
                    ),
                    if (countdown != null) ...[
                      SizedBox(height: Screen.getVerticalSize(8)),
                      Text(
                        countdown,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTextMedium.copyWith(
                          fontSize: Screen.getFontSize(12),
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(16)),
              Text(
                isLiveClass
                    ? 'This class has been scheduled by your educator. You '
                          'can join it once the session begins at the time '
                          'shown above.'
                    : 'This content has been scheduled by your educator and '
                          'is not available yet. It will open automatically '
                          'at the date and time shown above.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextMedium.copyWith(
                  fontSize: Screen.getFontSize(13),
                  color: AppColors.mutedTextPrimary,
                  height: 1.5,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(22)),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      height: Screen.getVerticalSize(48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Got It',
                        style: AppTypography.bodyTextLargeSemiBold.copyWith(
                          color: AppColors.alwaysWhite,
                          fontSize: Screen.getFontSize(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
