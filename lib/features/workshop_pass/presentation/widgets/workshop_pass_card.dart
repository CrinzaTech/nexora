import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';

/// The ticket itself, rendered from the server's own HTML.
///
/// **The artwork is not rebuilt natively, and that is the point.** One
/// shared Razor partial backs the organiser's preview, this screen and
/// the printed PDF, so the three cannot drift. A native reimplementation
/// looks identical right up until somebody recolours a design — and
/// nobody finds out until a door.
///
/// ## Why the height is measured rather than taken from `canvasHeight`
///
/// The payload advertises `720 × 340`, and sizing the box to that ratio
/// clipped the pass: the header and the date row fell outside it. The
/// declared canvas is what the design is *nominally* laid out for, not
/// what the document actually renders to — and while `pass_template_code`
/// is still null every workshop falls back to a design whose real height
/// is its own business.
///
/// So the document is asked how tall it is once it has laid itself out,
/// and the box is sized to the answer. `canvasWidth / canvasHeight` is
/// only the opening guess, used for the frame or two before the first
/// measurement lands.
///
/// Reading `scrollHeight` does not modify the document — the HTML is
/// still handed to `loadHtmlString` exactly as it arrived.
class WorkshopPassCard extends StatefulWidget {
  final WorkshopPass pass;

  const WorkshopPassCard({super.key, required this.pass});

  @override
  State<WorkshopPassCard> createState() => _WorkshopPassCardState();
}

class _WorkshopPassCardState extends State<WorkshopPassCard> {
  late WebViewController _controller;
  bool _isLoading = true;

  /// Width ÷ height of the document as it actually laid out. Null until
  /// the first measurement, when [WorkshopPass.aspectRatio] stands in.
  double? _measuredRatio;

  final List<Timer> _settleTimers = [];

  /// Asks the document for its own laid-out size.
  ///
  /// `clientWidth` rather than a hardcoded 720: the document sets its own
  /// viewport width, and reading it back means a design that ships a
  /// different one still measures correctly.
  static const String _measureJs = '''
(function () {
  var d = document.documentElement;
  var b = document.body;
  var rect = b ? b.getBoundingClientRect() : null;
  var cs = b ? window.getComputedStyle(b) : null;
  var mt = cs ? (parseFloat(cs.marginTop) || 0) : 0;
  var mb = cs ? (parseFloat(cs.marginBottom) || 0) : 0;
  // `scrollHeight` excludes the body's own margins, which is exactly the
  // slack that let the last row fall outside the box — so the margin box
  // is measured alongside it and the largest answer wins.
  var h = Math.max(
    d ? d.scrollHeight : 0, d ? d.offsetHeight : 0,
    b ? b.scrollHeight : 0, b ? b.offsetHeight : 0,
    rect ? Math.ceil(rect.height + mt + mb) : 0
  );
  var w = Math.max(
    d ? d.clientWidth : 0,
    b ? b.scrollWidth : 0,
    rect ? Math.ceil(rect.width) : 0
  );
  return w + 'x' + h;
})();
''';

  /// When to re-measure after the page reports itself finished.
  ///
  /// Web fonts arrive *after* that event and reflow the card when they
  /// land, and how long they take depends on the connection. One reading
  /// sizes the pass to its fallback-font layout and clips by the
  /// difference, so it is taken repeatedly over a few seconds. Content
  /// only grows as fonts swap in, so the latest answer is the right one.
  static const List<Duration> _remeasureAt = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 3000),
  ];

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.pass.html);
  }

  @override
  void didUpdateWidget(covariant WorkshopPassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A background refresh can replace a cached pass with a restyled
    // one. Same ticket, new artwork — reload rather than rebuild the
    // whole controller, so the card doesn't flash white in between. The
    // measurement is dropped with it: a new design is a new height.
    if (oldWidget.pass.html != widget.pass.html) {
      _isLoading = true;
      _measuredRatio = null;
      _cancelRemeasures();
      _controller.loadHtmlString(widget.pass.html);
    }
  }

  @override
  void dispose() {
    _cancelRemeasures();
    super.dispose();
  }

  void _cancelRemeasures() {
    for (final timer in _settleTimers) {
      timer.cancel();
    }
    _settleTimers.clear();
  }

  WebViewController _buildController(String html) {
    return WebViewController()
      // Needed even though the pass runs no scripts of its own — some
      // WebView builds will not settle Google Fonts without it, and the
      // measurement below is evaluated through it.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      // Pinch to zoom, handled by the WebView itself rather than by a
      // Flutter transform. A transform would scale the platform view's
      // rendered texture and go soft exactly when someone is zooming in
      // to read something small; the WebView re-renders at the new scale
      // and stays sharp. The pass sets no `user-scalable=no`, so this
      // takes effect.
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _measure();
            _cancelRemeasures();
            for (final delay in _remeasureAt) {
              _settleTimers.add(Timer(delay, _measure));
            }
          },
          onWebResourceError: (_) {
            // Google Fonts is the only thing this document ever fetches,
            // and it degrades to a system face. A failed font is not a
            // failed pass, so the card is shown either way.
            if (mounted) setState(() => _isLoading = false);
          },
          // A pass contains no links. Blocking navigation means a stray
          // tap can never replace the ticket with a web page mid-queue.
          onNavigationRequest: (_) => NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(html);
  }

  Future<void> _measure() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(_measureJs);
      if (!mounted) return;

      // Android hands this back as a JSON-encoded string, iOS as a plain
      // one — strip quotes rather than depend on which.
      final text = raw.toString().replaceAll('"', '').trim();
      final parts = text.split('x');
      if (parts.length != 2) return;

      final w = double.tryParse(parts[0]);
      final h = double.tryParse(parts[1]);
      if (w == null || h == null || w <= 0 || h <= 0) return;

      final ratio = w / h;
      if (_measuredRatio == ratio) return;
      setState(() => _measuredRatio = ratio);
    } catch (_) {
      // Measurement is an improvement on the declared canvas, never a
      // requirement — a WebView that refuses to evaluate keeps the
      // payload's own ratio.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _measuredRatio ?? widget.pass.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the whole ticket inside whatever room it is given —
        // width-led normally, height-led on a short screen or a landscape
        // phone. The pass is a thing you hold up; scrolling to see the
        // rest of it is not an option at a door.
        var width = constraints.maxWidth;
        var height = width / ratio;

        if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ColoredBox(
                    color: AppColors.white,
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading)
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
