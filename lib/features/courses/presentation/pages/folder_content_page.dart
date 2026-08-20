import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/widgets/module_card_widget.dart';
import 'package:flutter/material.dart';

/// Displays the children of a folder-type CourseContent
class FolderContentPage extends StatelessWidget {
  final CourseContent folder;
  final int courseId;

  /// Threaded through so nested [ModuleCard]s can build viewer URLs that
  /// carry completion-tracking args. `0` for non-purchased preview flows.
  final int coursePurchasedId;
  final bool activateWatermark;

  const FolderContentPage({
    super.key,
    required this.folder,
    required this.courseId,
    this.coursePurchasedId = 0,
    this.activateWatermark = false,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

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
                return ModuleCard(
                  module: item,
                  courseId: courseId,
                  coursePurchasedId: coursePurchasedId,
                  activateWatermark: activateWatermark,
                );
              },
            ),
    );
  }
}
