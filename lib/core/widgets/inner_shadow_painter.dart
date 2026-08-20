import 'package:flutter/material.dart';

/// Paints an inner shadow inside a rounded rectangle.
///
/// Flutter's BoxShadow only supports outer/drop shadows.
/// This CustomPainter renders an inset shadow by drawing a large
/// blurred rect outside the clip region so only the blur bleeds inward.
class InnerShadowPainter extends CustomPainter {
  final Color color;
  final double blurRadius;
  final Offset offset;
  final BorderRadius borderRadius;

  const InnerShadowPainter({
    required this.color,
    required this.blurRadius,
    this.offset = Offset.zero,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = borderRadius.toRRect(rect);

    // Clip to the rounded rect so only the inner part is visible
    canvas.save();
    canvas.clipRRect(rRect);

    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    // Draw a filled rect that sits outside the visible area,
    // shifted by offset. The blur bleeds inward through the clip.
    final outerRect = Rect.fromLTWH(
      -size.width + offset.dx,
      offset.dy,
      size.width * 3,
      size.height * 3,
    );

    // Punch a hole in the outer rect matching the card shape,
    // so only the shadow edges are painted inside.
    final path = Path()
      ..addRect(outerRect)
      ..addRRect(rRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(InnerShadowPainter oldDelegate) =>
      color != oldDelegate.color ||
      blurRadius != oldDelegate.blurRadius ||
      offset != oldDelegate.offset ||
      borderRadius != oldDelegate.borderRadius;
}
