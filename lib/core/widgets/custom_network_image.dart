import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Network image with consistent loading + error handling.
///
/// Wraps [CachedNetworkImage] and:
/// - Auto-derives a stable cache key via [Utils.imageCacheKey] so signed
///   URLs (whose signatures rotate) hit the same cache entry.
/// - Shows a shimmer-animated placeholder while loading. Failed loads
///   fall back to a flat grey box that matches the shimmer base colour.
/// - Renders the error fallback when the URL is null or empty, removing
///   the null-check boilerplate at every call site.
/// - Optionally wraps the image in [ClipRRect] when [borderRadius] is
///   set, replacing the surrounding `ClipRRect` boilerplate too.
class CustomNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Override the default shimmer placeholder. Pass a custom widget if a
  /// specific shape/colour is needed; otherwise the shimmer matches the
  /// rest of the app.
  final Widget? placeholder;

  /// Override the default error fallback. When `null`, a flat
  /// [AppColors.grey100] box is used.
  final Widget? errorWidget;

  const CustomNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  Widget _defaultPlaceholder() {
    // Same color palette as the rest of the app's shimmer skeletons
    // (see [_CourseListCardShimmer], [_NotificationListShimmer]).
    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white,
      child: Container(width: width, height: height, color: AppColors.grey200),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(width: width, height: height, color: AppColors.grey100);
  }

  @override
  Widget build(BuildContext context) {
    final src = url;
    final Widget child;

    if (src == null || src.isEmpty) {
      child = errorWidget ?? _defaultErrorWidget();
    } else {
      child = CachedNetworkImage(
        imageUrl: src,
        cacheKey: Utils.imageCacheKey(src),
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (_, __, ___) => errorWidget ?? _defaultErrorWidget(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
