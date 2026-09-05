import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/widgets/module_card_widget.dart';
import 'package:flutter/material.dart';

/// Displays the children of a folder-type CourseContent
class FolderContentPage extends StatefulWidget {
  final CourseContent folder;
  final int courseId;

  /// Threaded through so nested [ModuleCard]s can build viewer URLs that
  /// carry completion-tracking args. `0` for non-purchased preview flows.
  final int coursePurchasedId;
  final bool activateWatermark;

  /// A child to scroll to and highlight on arrival — the Home "Live
  /// classes" rail lands here for a nested live-class node. Null means
  /// the plain folder view.
  final String? focusNodeId;

  const FolderContentPage({
    super.key,
    required this.folder,
    required this.courseId,
    this.coursePurchasedId = 0,
    this.activateWatermark = false,
    this.focusNodeId,
  });

  @override
  State<FolderContentPage> createState() => _FolderContentPageState();
}

class _FolderContentPageState extends State<FolderContentPage> {
  final GlobalKey _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusNodeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.2,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    final folder = widget.folder;

    return Scaffold(
      appBar: CustomAppBar(
        title: folder.nodeName,
        centerTitle: true,
        titleColor: AppColors.textPrimary,
      ),
      body: folder.children.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: AppColors.grey300,
                  ),
                  SizedBox(height: Screen.getVerticalSize(15)),
                  Text(
                    "No content available",
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: Screen.getPadding(horizontal: 20, vertical: 16),
              itemCount: folder.children.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: Screen.getVerticalSize(10)),
              itemBuilder: (context, index) {
                final item = folder.children[index];
                if (!item.isVisible) return const SizedBox.shrink();
                final focused = widget.focusNodeId != null &&
                    item.nodeId == widget.focusNodeId;
                return ModuleCard(
                  key: focused ? _focusKey : null,
                  module: item,
                  courseId: widget.courseId,
                  coursePurchasedId: widget.coursePurchasedId,
                  activateWatermark: widget.activateWatermark,
                  highlighted: focused,
                );
              },
            ),
    );
  }
}
