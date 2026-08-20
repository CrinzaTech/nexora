import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Displays a PDF document from a network URL.
///
/// When [coursePurchasedId] and [nodeId] are both set, opening the page
/// fires the completion POST — documents complete on open, matching the
/// Office/other-document nodes that mark from the curriculum tile. Only
/// video keeps the 75% threshold.
class PdfViewerPage extends StatefulWidget {
  final String title;
  final String url;
  final bool showActions;
  final int coursePurchasedId;
  final String nodeId;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.url,
    this.showActions = true,
    this.coursePurchasedId = 0,
    this.nodeId = '',
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _controller = PdfViewerController();

  bool get _trackingEnabled =>
      widget.coursePurchasedId != 0 && widget.nodeId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Documents complete on open. Fired here rather than in the viewer's
    // `onDocumentLoaded` so a slow/failed render still counts — the
    // student did open the node, and the service owns delivery from
    // this point (queued + retried if the POST fails).
    if (_trackingEnabled) {
      sl<ContentCompletionService>().markCompleted(
        coursePurchasedId: widget.coursePurchasedId,
        jsonContentId: widget.nodeId,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Scaffold(
      // Soft grey backdrop behind the white PDF page — the previous
      // videoPlayerBgColor (near-black) clashed with the page edges.
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: widget.title,
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
      ),
      // Override Syncfusion's default pinkish backdrop around the page
      // with the same neutral grey as the scaffold.
      body: SfPdfViewerTheme(
        data: SfPdfViewerThemeData(backgroundColor: AppColors.grey100),
        child: SfPdfViewer.network(
          widget.url,
          controller: _controller,
          canShowScrollHead: false,
          // Page-per-screen layout, allow pinch/double-tap zoom.
          pageLayoutMode: PdfPageLayoutMode.single,
          initialZoomLevel: 1.0,
          maxZoomLevel: 4.0,
          enableDoubleTapZooming: true,
        ),
      ),
    );
  }
}
