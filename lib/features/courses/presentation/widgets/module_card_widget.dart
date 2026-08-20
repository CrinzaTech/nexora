import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/presentation/folder_navigation_cache.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tile for an individual content node — folder, video, image, document,
/// zip, or assignment.
class ModuleCard extends StatelessWidget {
  final CourseContent module;

  /// Course this node belongs to. Threaded through so assignment taps can
  /// push the assignment route with both `courseId` and `nodeId`.
  final int courseId;

  /// Server-side purchase row id for this user. When non-zero, viewers
  /// fire content-completion through [ContentCompletionService] at the
  /// per-type threshold (video/PDF 75%, image/assignment/zip on load).
  /// `0` means the user is previewing — completion tracking is skipped.
  final int coursePurchasedId;
  final bool activateWatermark;

  const ModuleCard({
    super.key,
    required this.module,
    required this.courseId,
    this.coursePurchasedId = 0,
    this.activateWatermark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (module.isVisible == false) {
      return const SizedBox.shrink();
    }
    // Live-class rows are time-dependent (upcoming → live → ended) but
    // the ListView is built once — rebuild them on a slow tick so the
    // "LIVE NOW" badge appears/expires without a manual refresh.
    if (module.isLiveClass) {
      return _PeriodicRebuild(
        interval: const Duration(seconds: 30),
        builder: (context) => _buildTile(context),
      );
    }
    return _buildTile(context);
  }

  Widget _buildTile(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: Screen.getVerticalSize(10)),
      decoration: BoxDecoration(
        border: Border.all(
          width: 1.5,
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: ListTile(
        dense: false,
        minTileHeight: 85,
        titleAlignment: ListTileTitleAlignment.center,
        onTap: () {
          if (module.isLocked) {
            CustomSnackbar.error(
              context,
              title: "Oops!",
              message:
                  "This content is locked. Please enroll in the course to access it.",
            );
            return;
          }
          // Common query-param pair appended to every viewer route so
          // it can fire the /completion POST at the right threshold.
          // Empty when the user is previewing — viewers skip tracking.
          final completionArgs = '&coursePurchasedId=$coursePurchasedId'
              '&nodeId=${Uri.encodeComponent(module.nodeId)}';

          if (module.isFolder) {
            // Folders never count towards completion. Just navigate.
            // courseId + coursePurchasedId travel through so deeper
            // nodes can build their own viewer URLs.
            FolderNavigationCache.put(module);
            context.push(
              '${AppRoutes.folderContent}'
              '?folderId=${Uri.encodeComponent(module.nodeId)}'
              '&courseId=$courseId'
              '&coursePurchasedId=$coursePurchasedId'
              '&activateWatermark=$activateWatermark',
            );
          } else if (module.type == CourseContentType.document &&
              module.pdfUrl != null) {
            final path = Uri.tryParse(module.pdfUrl!)?.path.toLowerCase() ?? '';
            if (path.endsWith('.doc') ||
                path.endsWith('.docx') ||
                path.endsWith('.xls') ||
                path.endsWith('.xlsx') ||
                path.endsWith('.ppt') ||
                path.endsWith('.pptx')) {
              if (coursePurchasedId != 0 && module.nodeId.isNotEmpty) {
                sl<ContentCompletionService>().markCompleted(
                  coursePurchasedId: coursePurchasedId,
                  jsonContentId: module.nodeId,
                );
              }
              final officeUrl =
                  'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(module.pdfUrl!)}';
              context.push(
                '${AppRoutes.documentViewer}'
                '?title=${Uri.encodeComponent(module.nodeName)}'
                '&url=${Uri.encodeComponent(officeUrl)}',
              );
            } else if (path.endsWith('.pdf')) {
              context.push(
                '${AppRoutes.pdfViewer}'
                '?title=${Uri.encodeComponent(module.nodeName)}'
                '&url=${Uri.encodeComponent(module.pdfUrl!)}'
                '$completionArgs',
              );
            } else {
              if (coursePurchasedId != 0 && module.nodeId.isNotEmpty) {
                sl<ContentCompletionService>().markCompleted(
                  coursePurchasedId: coursePurchasedId,
                  jsonContentId: module.nodeId,
                );
              }
              if (module.pdfUrl!.toLowerCase().startsWith('http')) {
                context.push(
                  '${AppRoutes.documentViewer}'
                  '?title=${Uri.encodeComponent(module.nodeName)}'
                  '&url=${Uri.encodeComponent(module.pdfUrl!)}',
                );
              } else {
                launchUrl(Uri.parse(module.pdfUrl!), mode: LaunchMode.externalApplication);
              }
            }
          } else if ((module.type == CourseContentType.video ||
                  module.type == CourseContentType.youtube) &&
              module.primaryUrl != null) {
            // Both regular MP4 and YouTube nodes go to the same player
            // page — it detects the URL flavour internally and swaps
            // the renderer. Using `primaryUrl` instead of `videoUrl`
            // because `videoUrl` is type-gated to `video` only.
            context.push(
              '${AppRoutes.videoPlayer}'
              '?title=${Uri.encodeComponent(module.nodeName)}'
              '&url=${Uri.encodeComponent(module.primaryUrl!)}'
              '$completionArgs'
              '&activateWatermark=$activateWatermark',
            );
          } else if (module.type == CourseContentType.image &&
              module.imageUrl != null) {
            context.push(
              '${AppRoutes.imageViewer}'
              '?title=${Uri.encodeComponent(module.nodeName)}'
              '&url=${Uri.encodeComponent(module.imageUrl!)}'
              '$completionArgs',
            );
          } else if (module.type == CourseContentType.assignment) {
            // The assignment row id lives in the curriculum node's `url`
            // field — fall back to 0 if the backend ships a non-numeric
            // value so the router can surface "Invalid assignment id"
            // instead of silently mis-routing.
            final assignmentId = int.tryParse(module.url ?? '') ?? 0;
            context.push(
              '${AppRoutes.assignment}'
              '?assignmentId=$assignmentId'
              '&courseId=$courseId'
              '&nodeId=${Uri.encodeComponent(module.nodeId)}'
              '&coursePurchasedId=$coursePurchasedId',
            );
          } else if (module.type == CourseContentType.exam) {
            // The exam id lives in the curriculum node's `url` field —
            // fall back to 0 so the router surfaces "Invalid exam id"
            // instead of silently mis-routing. Completion is fired inside
            // ExamPage on load (parity with image/assignment nodes).
            final examId = int.tryParse(module.url ?? '') ?? 0;
            context.push(
              '${AppRoutes.exam}'
              '?examId=$examId'
              '&courseId=$courseId'
              '&nodeId=${Uri.encodeComponent(module.nodeId)}'
              '&coursePurchasedId=$coursePurchasedId',
            );
          } else if (module.type == CourseContentType.liveClass) {
            if (module.isEnded) {
              CustomSnackbar.info(
                context,
                title: 'Class ended',
                message: 'This class has ended.',
              );
            } else if (module.isUpcoming) {
              // Joining is blocked until the scheduled start time — the
              // row rebuilds on the 30s tick, so it becomes tappable on
              // its own once the class window opens.
              CustomSnackbar.info(
                context,
                title: 'Not started yet',
                message:
                    'This class starts ${_formatStartTime(module.startDateTime!)}. '
                    'You can join once it begins.',
              );
            } else if ((module.url ?? '').isNotEmpty) {
              // Only a class inside its scheduled window reaches here.
              // `url` carries the roomId; the page resolves the signed
              // HLS URL + hub token itself. `scheduledAt` (local ISO)
              // seeds the waiting countdown while the host is yet to go
              // on air.
              final scheduledArg = module.startDateTime != null
                  ? '&scheduledAt=${Uri.encodeComponent(module.startDateTime!.toIso8601String())}'
                  : '';
              context.push(
                '${AppRoutes.liveClass}'
                '?title=${Uri.encodeComponent(module.nodeName)}'
                '&url=${Uri.encodeComponent(module.url!)}'
                '&courseId=$courseId'
                '$scheduledArg'
                '$completionArgs'
                '&activateWatermark=$activateWatermark',
              );
            } else {
              CustomSnackbar.error(
                context,
                title: 'Oops!',
                message: 'This live class is not available right now.',
              );
            }
          } else if (module.type == CourseContentType.zip) {
            // Zips have no in-app viewer — tapping counts as "consumed"
            // (per spec: image/assignment/zip fire on load). Mark the
            // node complete and acknowledge with a snackbar; downloading
            // through the OS browser can be wired separately later.
            //
            // The confirmation is gated on tracking actually being on:
            // in a preview flow (coursePurchasedId 0) the service no-ops,
            // so an unconditional "Saved to your progress" would be a lie.
            if (coursePurchasedId != 0 && module.nodeId.isNotEmpty) {
              sl<ContentCompletionService>().markCompleted(
                coursePurchasedId: coursePurchasedId,
                jsonContentId: module.nodeId,
              );
              CustomSnackbar.success(
                context,
                title: 'Marked as completed',
                message: 'Saved to your progress.',
              );
            }
          } else {
            // Reached only when a non-folder node carries no usable URL —
            // `document`/`video`/`youtube`/`image` all derive their URL
            // from the same nullable `url` field, so a curriculum row
            // saved without one lands here. Previously this fell through
            // every branch and the tap did nothing at all: no viewer, no
            // completion, and no indication to the student that anything
            // was wrong. Surface it instead of failing silently.
            debugPrint(
              'ModuleCard: node "${module.nodeName}" (${module.type}, '
              'nodeId=${module.nodeId}) has no usable url — cannot open '
              'or record completion.',
            );
            CustomSnackbar.error(
              context,
              title: 'Oops!',
              message: "This content isn't available right now.",
            );
          }
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        leading: SizedBox.square(
          dimension: Screen.getVerticalSize(50),
          child: _getLeading(module),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module.nodeName,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                fontSize: rh.isLargeScreen ? rh.cappedFontSize(14) : Screen.getFontSize(14),
              ),
            ),
            if ((module.type == CourseContentType.video ||
                    module.type == CourseContentType.youtube) &&
                module.formattedDuration != null) ...[
              SizedBox(height: Screen.getVerticalSize(5)),
              Text(
                module.formattedDuration!,
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12),
                ),
              ),
            ],
            if (module.type == CourseContentType.document)
              Text(
                _getDocumentLabel(module.pdfUrl),
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12),
                ),
              ),

            if (module.type == CourseContentType.image)
              Text(
                "Image",
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12),
                ),
              ),

            if (module.type == CourseContentType.assignment)
              Text(
                "Assignment",
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12),
                ),
              ),

            if (module.type == CourseContentType.exam)
              Text(
                "Exam",
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12),
                ),
              ),

            if (module.type == CourseContentType.liveClass) ...[
              SizedBox(height: Screen.getVerticalSize(5)),
              _buildLiveClassSubtitle(rh),
            ],
          ],
        ),
        trailing: _getTrailing(module),
      ),
    );
  }

  /// Coloured status pill for a live-class row, derived from the node's
  /// time state at build time (the row rebuilds on a 30s tick).
  Widget _buildLiveClassSubtitle(ResponsiveHelper rh) {
    final fontSize =
        rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12);
    if (module.isLiveNow) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: Screen.getSize(8), color: AppColors.error),
          SizedBox(width: Screen.getHorizontalSize(5)),
          Text(
            'LIVE NOW',
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: AppColors.error,
              fontSize: fontSize,
            ),
          ),
        ],
      );
    }
    if (module.isUpcoming) {
      return Text(
        'Starts ${_formatStartTime(module.startDateTime!)}',
        style: AppTypography.bodyTextMedium.copyWith(
          color: AppColors.mutedTextPrimary,
          fontSize: fontSize,
        ),
      );
    }
    return Text(
      module.isEnded ? 'Ended' : 'Live Class',
      style: AppTypography.bodyTextMedium.copyWith(
        color: AppColors.mutedTextPrimary,
        fontSize: fontSize,
      ),
    );
  }

  /// "Today, 5:30 PM" / "Tomorrow, 5:30 PM" / "12 Aug, 5:30 PM".
  /// [start] is already local time (converted at parse).
  static String _formatStartTime(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final time = DateFormat('h:mm a').format(start);
    if (startDay == today) return 'Today, $time';
    if (startDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow, $time';
    }
    return '${DateFormat('d MMM').format(start)}, $time';
  }
}

/// Rebuilds [builder] every [interval] — used so time-dependent rows
/// (live-class badges) refresh inside a ListView that is built once.
class _PeriodicRebuild extends StatefulWidget {
  final Duration interval;
  final WidgetBuilder builder;

  const _PeriodicRebuild({required this.interval, required this.builder});

  @override
  State<_PeriodicRebuild> createState() => _PeriodicRebuildState();
}

class _PeriodicRebuildState extends State<_PeriodicRebuild> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _getLeading(CourseContent module) {
  switch (module.type) {
    case CourseContentType.folder:
      return Image.asset(
        AppImages.folderIcon,
        width: Screen.getSize(16),
        height: Screen.getSize(16),
      );
    case CourseContentType.video:
    case CourseContentType.youtube:
      // YouTube nodes deliberately use the same icon as a regular video
      // node — the curriculum list shouldn't reveal that some lectures
      // are externally hosted.
      return Image.asset(
        AppImages.videoIcon,
        width: Screen.getSize(16),
        height: Screen.getSize(16),
      );
    case CourseContentType.image:
    case CourseContentType.document:
    case CourseContentType.zip:
      return Image.asset(
        AppImages.documentIconColored,
        width: Screen.getSize(16),
        height: Screen.getSize(16),
      );
    case CourseContentType.assignment:
      // No dedicated assignment asset yet — re-use the document icon so
      // the row stays visually consistent with PDF/image entries.
      return Icon(
        Icons.assignment_outlined,
        size: Screen.getSize(20),
        color: AppColors.primary,
      );
    case CourseContentType.exam:
      return Icon(
        Icons.quiz_outlined,
        size: Screen.getSize(20),
        color: AppColors.primary,
      );
    case CourseContentType.liveClass:
      // Broadcast icon, tinted red while the class is on air and muted
      // once it has ended.
      return Icon(
        Icons.sensors,
        size: Screen.getSize(20),
        color: module.isLiveNow
            ? AppColors.error
            : (module.isEnded ? AppColors.mutedTextPrimary : AppColors.primary),
      );
  }
}

Widget? _getTrailing(CourseContent module) {
  if (module.isLocked) {
    return Image.asset(
      AppImages.passwordIcon,
      width: Screen.getSize(20),
      height: Screen.getSize(20),
      color: AppColors.mutedTextPrimary,
    );
  }
  if (module.type == CourseContentType.folder) {
    return Image.asset(
      AppImages.arrowRightIcon,
      width: Screen.getSize(20),
      height: Screen.getSize(20),
      color: AppColors.mutedTextPrimary,
    );
  }
  if (module.type == CourseContentType.liveClass && module.isUpcoming) {
    // Not joinable until the scheduled time — a muted clock instead of
    // the "Join" pill, so the row reads as unavailable before it is
    // tapped (the tap explains when it opens).
    return Icon(
      Icons.schedule,
      size: Screen.getSize(20),
      color: AppColors.mutedTextPrimary,
    );
  }
  if (module.type == CourseContentType.liveClass && module.isLiveNow) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppSizes.borderRadiusCircle,
      ),
      child: Text(
        'Join',
        style: AppTypography.labelSmall.copyWith(color: AppColors.alwaysWhite),
      ),
    );
  }
  return null;
}

String _getDocumentLabel(String? url) {
  if (url == null) return "Document";
  final lowerUrl = url.toLowerCase();
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.pdf')) return "PDF";
  if (path.endsWith('.doc') || path.endsWith('.docx') || lowerUrl.contains('docs.google.com/document')) return "Word Document";
  if (path.endsWith('.xls') || path.endsWith('.xlsx') || lowerUrl.contains('docs.google.com/spreadsheets')) return "Excel Sheet";
  if (path.endsWith('.ppt') || path.endsWith('.pptx') || lowerUrl.contains('docs.google.com/presentation')) return "Presentation";
  if (lowerUrl.contains('docs.google.com/forms')) return "Google Form";
  if (lowerUrl.contains('drive.google.com')) return "Google Drive Link";
  return "Document";
}
