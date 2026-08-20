import 'dart:async';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerSection extends StatefulWidget {
  final List<BannerItem> banners;

  const BannerSection({super.key, required this.banners});

  @override
  State<BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends State<BannerSection> {
  /// We feed PageView an unbounded `itemCount` and seat the user in the
  /// middle of the virtual index space so swipes work in both directions
  /// forever without ever hitting an edge. A constant this large is
  /// effectively infinite at one swipe per second — even a year of
  /// continuous use can't reach the boundary.
  static const int _initialPage = 100000;

  late final PageController _controller;
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Anchor `_initialPage` to a multiple of the banner count so the
    // first visible banner is index 0 (otherwise modulo lands somewhere
    // in the middle of the list).
    final anchored = widget.banners.isEmpty
        ? _initialPage
        : _initialPage - (_initialPage % widget.banners.length);
    _controller = PageController(initialPage: anchored);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gate the auto-advance ticker on the ambient TickerMode — when the
    // user navigates to a different tab the dashboard disables tickers
    // on the off-screen subtree, and we cancel our Timer in lockstep.
    // Without this, the carousel keeps animating + decoding network
    // images while invisible, burning CPU and waking the rasterizer
    // for no rendered output.
    final tickerActive = TickerMode.of(context);
    if (tickerActive && widget.banners.length > 1) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_controller.hasClients || !mounted) return;
      final current = _controller.page?.round() ?? 0;
      _controller.animateToPage(
        current + 1,
        curve: Curves.easeInOutCubic,
        duration: const Duration(milliseconds: 1500),
      );
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _controller.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  /// Banner tap router.
  ///
  /// Branches on [BannerItem.ctaTypeEnum]:
  ///   - `none` / `unknown`    → no-op (banner is purely decorative)
  ///   - `specificCourse`      → course-detail page  (?courseId= &title=ctaName)
  ///   - `specificTile`        → catalog filtered by tile (?tileId= &title=ctaName)
  ///   - `externalLink`        → system browser via `url_launcher`
  void _handleBannerTap(BuildContext context, BannerItem banner) {
    final ref = banner.ctaLink.trim();

    // ── Debug: print the raw fields so we can verify the API payload ──
    debugPrint(
      '[BannerTap] bannerId=${banner.bannerId}'
      ' ctaType(raw)="${banner.ctaType}"'
      ' ctaTypeEnum=${banner.ctaTypeEnum}'
      ' ctaLink="${banner.ctaLink}"'
      ' ctaName="${banner.ctaName}"',
    );

    switch (banner.ctaTypeEnum) {
      case BannerCtaType.specificCourse:
        final courseId = int.tryParse(ref);
        if (courseId == null) return;
        final courseName = banner.ctaName.trim();
        context.push(
          courseName.isNotEmpty
              ? '${AppRoutes.courseDetail}?courseId=$courseId&title=${Uri.encodeComponent(courseName)}'
              : '${AppRoutes.courseDetail}?courseId=$courseId',
        );
        return;
      case BannerCtaType.specificTile:
        final tileId = int.tryParse(ref);
        if (tileId == null) return;
        // ctaName is sent by the API — use it directly as the AppBar title.
        final tileName = banner.ctaName.trim();
        context.push(
          '${AppRoutes.catalog}?tileId=$tileId'
          '&title=${Uri.encodeComponent(tileName.isNotEmpty ? tileName : 'Courses')}',
        );
        return;
      case BannerCtaType.externalLink:
        if (ref.isEmpty) return;
        _openExternal(context, ref);
        return;
      case BannerCtaType.none:
      case BannerCtaType.unknown:
        return;
    }
  }

  /// Fire-and-forget URL launch. Mirrors the notification page's
  /// [_openExternal]: one snackbar on failure so the user knows the
  /// tap didn't silently do nothing.
  Future<void> _openExternal(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      CustomSnackbar.error(context, title: 'Could not open link', message: raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // AspectRatio(16:9) instead of a fixed pixel height so the
        // container adapts to any banner image without ever cropping it.
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            padEnds: false,
            controller: _controller,
            // `null` → unbounded PageView. Combined with the modulo in
            // itemBuilder this gives a seamless infinite carousel that
            // can be swiped either direction.
            itemCount: null,
            onPageChanged: (virtualIndex) {
              _currentIndex.value = virtualIndex % widget.banners.length;
            },
            itemBuilder: (context, virtualIndex) {
              final banner =
                  widget.banners[virtualIndex % widget.banners.length];
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleBannerTap(context, banner),
                  child: CustomNetworkImage(
                    url: banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    // Lightweight fallback — a soft grey tile with an
                    // image-not-supported glyph. The previous bundled PNG
                    // was a 4.3 MB 4K asset, way too heavy for an error
                    // placeholder that may never render.
                    errorWidget: Container(
                      color: AppColors.grey100,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.grey300,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        _DotsIndicator(
          currentIndex: _currentIndex,
          count: widget.banners.length,
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final ValueNotifier<int> currentIndex;
  final int count;

  const _DotsIndicator({required this.currentIndex, required this.count});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentIndex,
      builder: (context, index, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final isActive = index == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 5,
              width: isActive ? 30 : 5,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.grey200,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        );
      },
    );
  }
}
