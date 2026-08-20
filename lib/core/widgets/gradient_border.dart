import 'package:flutter/material.dart';

/// Custom border that renders a gradient instead of a solid color
class GradientBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBorder({required this.gradient, this.width = 1.0});

  @override
  BorderSide get top => BorderSide.none;
  @override
  BorderSide get bottom => BorderSide.none;

  @override
  bool get isUniform => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);

    final rRect =
        borderRadius?.toRRect(rect).deflate(width / 2) ??
        RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.zero);

    canvas.drawRRect(rRect, paint);
  }

  @override
  ShapeBorder scale(double t) =>
      GradientBorder(gradient: gradient, width: width * t);
}
