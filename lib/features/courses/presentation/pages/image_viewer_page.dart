import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:flutter/material.dart';

/// Displays an image curriculum node — pinch-to-zoom enabled, dark
/// backdrop matching the PDF / video viewers.
///
/// When [coursePurchasedId] and [nodeId] are both supplied, completion
/// is recorded as soon as the page mounts (per the spec — image nodes
/// count as "consumed" the moment they load on screen). The service's
/// session cache dedups so revisiting is a no-op.
class ImageViewerPage extends StatefulWidget {
  final String title;
  final String url;
  final int coursePurchasedId;
  final String nodeId;

  const ImageViewerPage({
    super.key,
    required this.title,
    required this.url,
    this.coursePurchasedId = 0,
    this.nodeId = '',
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    if (widget.coursePurchasedId != 0 && widget.nodeId.isNotEmpty) {
      // Fire-and-forget. The service de-dupes per session, so re-entering
      // the page won't re-POST.
      sl<ContentCompletionService>().markCompleted(
        coursePurchasedId: widget.coursePurchasedId,
        jsonContentId: widget.nodeId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return Scaffold(
      backgroundColor: AppColors.videoPlayerBgColor,
      appBar: CustomAppBar(
        title: widget.title,
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          child: CustomNetworkImage(
            url: widget.url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorWidget: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: AppColors.grey300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load image',
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.alwaysWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
