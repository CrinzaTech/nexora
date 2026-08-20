import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';

/// Live countdown chip driven by an absolute [deadlineUtc]. Fires
/// [onExpired] exactly once when the deadline passes. Turns amber under
/// 5 min and red under 1 min.
class ExamCountdown extends StatefulWidget {
  final DateTime deadlineUtc;
  final VoidCallback onExpired;

  const ExamCountdown({
    super.key,
    required this.deadlineUtc,
    required this.onExpired,
  });

  @override
  State<ExamCountdown> createState() => _ExamCountdownState();
}

class _ExamCountdownState extends State<ExamCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Duration _compute() {
    final diff = widget.deadlineUtc.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _tick() {
    final next = _compute();
    if (mounted) setState(() => _remaining = next);
    if (next == Duration.zero && !_fired) {
      _fired = true;
      _timer?.cancel();
      // Defer so we never call back mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Color get _color {
    if (_remaining.inSeconds <= 60) return AppColors.error;
    if (_remaining.inMinutes < 5) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: _color),
          const SizedBox(width: 6),
          Text(
            _label,
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: _color,
              fontFeatures: const [], // keep tabular-ish spacing simple
            ),
          ),
        ],
      ),
    );
  }
}
