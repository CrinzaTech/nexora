import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';

/// The saved pass PDF, opened straight after "Save as PDF".
///
/// Opening it immediately is the expected outcome of saving — a snackbar
/// saying "saved to documents" leaves the attendee hunting for a file
/// manager. The share action here is what turns "save" into "send my
/// ticket to whoever is driving me there".
///
/// The file is already on disk, so this uses [SfPdfViewer.file] rather
/// than the `.network` constructor: the download needs the JWT, which
/// the viewer cannot attach for itself.
class WorkshopPassPdfPage extends StatelessWidget {
  final DownloadedPass pass;

  const WorkshopPassPdfPage({super.key, required this.pass});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: 'Entry pass',
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: Icon(Icons.ios_share_rounded, color: AppColors.white),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pass.passNo.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.videoPlayerBgColor,
              padding: Screen.getPadding(horizontal: 20, bottom: 12),
              child: Text(
                'Pass No. ${pass.passNo}',
                textAlign: TextAlign.center,
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.white.withValues(alpha: 0.75),
                  fontSize: Screen.getFontSize(12),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          Expanded(
            child: SfPdfViewerTheme(
              data: SfPdfViewerThemeData(backgroundColor: AppColors.grey100),
              child: SfPdfViewer.file(
                File(pass.path),
                canShowScrollHead: false,
                // A single 720×340pt card, not a document — fit the
                // whole ticket on screen rather than paging it.
                pageLayoutMode: PdfPageLayoutMode.single,
                initialZoomLevel: 1.0,
                maxZoomLevel: 4.0,
                enableDoubleTapZooming: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    // iPad presents the share sheet as a popover anchored to the
    // originating widget — without an origin rect it throws.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pass.path, mimeType: 'application/pdf')],
          subject: '${pass.workshopTitle} Entry pass',
          text: pass.passNo.isEmpty
              ? 'My entry pass for ${pass.workshopTitle}.'
              : 'My entry pass for ${pass.workshopTitle} (${pass.passNo}).',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(
          context,
          title: 'Cannot Share',
          message: 'Unable to open the share sheet.',
        );
      }
    }
  }
}
