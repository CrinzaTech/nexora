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
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';

/// Shows a certificate that has already been downloaded to the device.
///
/// The file is local, so this uses [SfPdfViewer.file] rather than the
/// `.network` constructor the course document viewer uses — the download
/// needs the JWT, which the viewer can't attach on its own.
class CertificatePreviewPage extends StatelessWidget {
  final DownloadedCertificate certificate;

  const CertificatePreviewPage({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    final file = File(certificate.path);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: 'Certificate',
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
          // The number is the thing a learner quotes to an employer, and
          // the PDF renders it small — repeat it above the page so it can
          // be read (and copied out of a screenshot) at a glance.
          if (certificate.certificateNo.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.videoPlayerBgColor,
              padding: Screen.getPadding(horizontal: 20, bottom: 12),
              child: Text(
                'Certificate No. ${certificate.certificateNo}',
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
                file,
                canShowScrollHead: false,
                // A4 landscape — fit the whole certificate on screen
                // instead of the vertical page-per-screen layout the
                // course document viewer uses for portrait notes.
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
          files: [XFile(certificate.path, mimeType: 'application/pdf')],
          subject: '${certificate.courseName} Certificate',
          text: certificate.certificateNo.isEmpty
              ? 'My certificate for ${certificate.courseName}.'
              : 'My certificate for ${certificate.courseName} '
                    '(${certificate.certificateNo}).',
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
