import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable gradient blobs widget with configurable positioning and sizing
///
/// Provides soft colored circles that can be blurred for premium gradient effects.
/// Commonly used with [BackdropFilter] for blurred gradient backgrounds.
class GradientBlobs extends StatelessWidget {
  /// Create gradient blobs with custom configuration
  const GradientBlobs({
    super.key,
    this.blobs = const [
      BlobConfig(
        color: Color(0xFF6C63FF),
        alignment: Alignment(-1.2, -0.8),
      ),
      BlobConfig(
        color: Color(0xFFF472B6),
        alignment: Alignment(1.2, 0.8),
      ),
    ],
    this.sizeMultiplier = 1.75,
    this.useScreenSize = true,
    this.customSize,
  });

  /// Create gradient blobs centered on screen
  const GradientBlobs.centered({
    super.key,
    this.blobs = const [
      BlobConfig(
        color: Color(0xFF6C63FF),
        alignment: Alignment(-0.5, 0),
      ),
      BlobConfig(
        color: Color(0xFFF472B6),
        alignment: Alignment(0.5, 0),
      ),
    ],
    this.sizeMultiplier = 1.5,
    this.useScreenSize = true,
    this.customSize,
  });

  /// Create gradient blobs for top accent
  const GradientBlobs.top({
    super.key,
    this.blobs = const [
      BlobConfig(
        color: Color(0xFF6C63FF),
        alignment: Alignment(0, -1.5),
      ),
    ],
    this.sizeMultiplier = 1.5,
    this.useScreenSize = true,
    this.customSize,
  });

  /// Create gradient blobs for bottom accent
  const GradientBlobs.bottom({
    super.key,
    this.blobs = const [
      BlobConfig(
        color: Color(0xFFF472B6),
        alignment: Alignment(0, 1.5),
      ),
    ],
    this.sizeMultiplier = 1.5,
    this.useScreenSize = true,
    this.customSize,
  });

  /// Configuration for each blob
  final List<BlobConfig> blobs;

  /// Default size multiplier relative to screen width (only used if [useScreenSize] is true
  /// and blob doesn't have its own size)
  final double sizeMultiplier;

  /// Whether to calculate size based on screen width
  final bool useScreenSize;

  /// Custom fixed size for all blobs (overrides [sizeMultiplier] and [useScreenSize],
  /// but blob-specific sizes take precedence)
  final double? customSize;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate default blob size (fallback)
    final defaultBlobSize = customSize ?? (useScreenSize ? screenWidth * sizeMultiplier : 200);

    return Stack(
      children: blobs.map((blob) {
        // Calculate size for this blob (use blob's size if provided, otherwise use default)
        final blobSize = blob.customSize ??
            (blob.sizeMultiplier != null ? screenWidth * blob.sizeMultiplier! : defaultBlobSize);

        // Calculate position from alignment
        final xOffset = blob.alignment.x * (screenWidth / 2);
        final yOffset = blob.alignment.y * (screenHeight / 2);

        return Positioned(
          left: screenWidth / 2 + xOffset - blobSize / 2,
          top: screenHeight / 2 + yOffset - blobSize / 2,
          child: _ColorBlob(
            color: blob.color,
            size: blobSize,
          ),
        );
      }).toList(),
    );
  }
}

/// Configuration for a single gradient blob
class BlobConfig {
  const BlobConfig({
    required this.color,
    required this.alignment,
    this.sizeMultiplier,
    this.customSize,
  });

  /// Color of the blob
  final Color color;

  /// Position alignment (-1 to 1 range for x and y)
  /// Example: Alignment(-1, -1) = top-left, Alignment(1, 1) = bottom-right
  /// Values outside -1 to 1 will position the blob partially off-screen
  final Alignment alignment;

  /// Size multiplier for this specific blob (relative to screen width)
  /// If null, uses the global [GradientBlobs.sizeMultiplier]
  final double? sizeMultiplier;

  /// Custom fixed size for this blob (overrides both size multipliers)
  /// If null, uses [sizeMultiplier] or falls back to global multiplier
  final double? customSize;
}

/// Individual color blob widget
class _ColorBlob extends StatelessWidget {
  const _ColorBlob({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-configured blur effect wrapper for gradient blobs
///
/// Wraps [GradientBlobs] with a [BackdropFilter] for the classic blurred gradient effect.
class BlurredGradientBlobs extends StatelessWidget {
  const BlurredGradientBlobs({
    super.key,
    this.blobs,
    this.blurSigma = 120.0,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  }) : assert(
          overlayColor == null || overlayOpacity >= 0 && overlayOpacity <= 1,
          'overlayOpacity must be between 0 and 1',
        );

  /// The gradient blobs to blur (uses default corner blobs if not provided)
  final GradientBlobs? blobs;

  /// Blur intensity (higher = more diffuse)
  final double blurSigma;

  /// Optional overlay color (typically white) to soften the gradient
  final Color? overlayColor;

  /// Opacity of the overlay color (0.0 = transparent, 1.0 = solid)
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Color blobs layer
        blobs ?? const GradientBlobs(),

        // Blur effect over blobs
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: ColoredBox(
                color: (overlayColor ?? AppColors.white).withValues(
                  alpha: overlayOpacity,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
