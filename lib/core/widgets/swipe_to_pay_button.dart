import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/inner_shadow_painter.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SwipeToPayButton extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;

  const SwipeToPayButton({
    super.key,
    required this.onSwipeComplete,
    this.text = 'Proceed to Pay Securely',
  });

  @override
  State<SwipeToPayButton> createState() => _SwipeToPayButtonState();
}

class _SwipeToPayButtonState extends State<SwipeToPayButton>
    with SingleTickerProviderStateMixin {
  bool _isCompleted = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // 0.0 to 1.0 representing percentage of completion
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isCompleted || maxDrag == 0) return;
    _animationController.value += details.delta.dx / maxDrag;
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_isCompleted) return;

    if (_animationController.value > 0.75) {
      // Completed
      _animationController.forward().then((_) {
        setState(() {
          _isCompleted = true;
        });
        widget.onSwipeComplete();
      });
    } else {
      // Snap back
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbSize = Screen.getVerticalSize(54);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - thumbSize - 8.0).clamp(
          0.0,
          double.infinity,
        );

        return Container(
          height: thumbSize + 8,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.mutedTextPrimary.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Inner shadow for recessed look
              Positioned.fill(
                child: CustomPaint(
                  painter: InnerShadowPainter(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // Background text
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (1 - _animationController.value).clamp(0.0, 1.0),
                      child: child!,
                    );
                  },
                  child: Shimmer.fromColors(
                    baseColor: AppColors.primary,
                    highlightColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),

              // Filled track behind thumb
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final dragPos = _animationController.value * maxDrag;
                  if (dragPos <= 0) return const SizedBox.shrink();
                  return Positioned(
                    left: 4,
                    top: 4,
                    bottom: 4,
                    child: Container(
                      width: dragPos + (thumbSize / 2),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          AppColors.primary.withValues(alpha: 0.4),
                          AppColors.success.withValues(alpha: 0.5),
                          _animationController.value,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(100),
                          bottomLeft: Radius.circular(100),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Thumb
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final dragPos = _animationController.value * maxDrag;
                  return Positioned(
                    left: dragPos + 4,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) =>
                          _onDragUpdate(details, maxDrag),
                      onHorizontalDragEnd: (details) =>
                          _onDragEnd(details, maxDrag),
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child:
                              _isCompleted || _animationController.value == 1.0
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.alwaysWhite,
                                )
                              : Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: AppColors.alwaysWhite,
                                  size: Screen.getSize(24),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
