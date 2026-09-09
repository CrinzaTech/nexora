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
import 'package:nexora/features/courses/data/services/live_status_probe.dart';
import 'package:nexora/features/courses/presentation/folder_navigation_cache.dart';
import 'package:nexora/features/courses/presentation/widgets/scheduled_content_dialog.dart';
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

  /// Deep-linked to (the Home "Live classes" rail): a brief tinted pulse
  /// so the learner's eye lands on this row. No other behaviour change.
  final bool highlighted;

  const ModuleCard({
    super.key,
    required this.module,
    required this.courseId,
    this.coursePurchasedId = 0,
    this.activateWatermark = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (module.isVisible == false) {
      return const SizedBox.shrink();
    }
    Widget tile(BuildContext context) {
      if (!highlighted) return _buildTile(context);
      // Primary at ~8%, fading out over 1.5s.
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOut,
        builder: (context, t, _) => _buildTile(context, tint: t),
      );
    }

    // Live-class rows are time-dependent (upcoming → live → ended) but
    // the ListView is built once — rebuild them on a slow tick so the
    // "LIVE NOW" badge appears/expires without a manual refresh.
    if (module.isLiveClass) {
      return _PeriodicRebuild(
        interval: const Duration(seconds: 30),
        // A probe verdict landing corrects the badge immediately
        // instead of waiting for the next tick.
        listenable: sl<LiveStatusProbe>(),
        builder: tile,
      );
    }
    // Same treatment for a node with a scheduled release time: tick so
    // the row flips from "Unlocks …" to openable on its own when the
    // moment passes, instead of stranding the student on a stale tile.
    if (module.isScheduleLocked) {
      return _PeriodicRebuild(
        interval: const Duration(seconds: 30),
        builder: tile,
      );
    }
    return tile(context);
  }

  /// The schedule window is open but the stream server says nothing is
  /// being broadcast — the host hasn't started yet, or the admin ended
  /// the class early. The curriculum API carries no live status, so the
  /// stream itself is the only truth the badge can check. Optimistic on
  /// `unknown` (never probed / network error): the schedule-derived
  /// badge stands until the probe says otherwise.
  bool get _offAir =>
      module.isLiveNow &&
      (module.url ?? '').isNotEmpty &&
      sl<LiveStatusProbe>().statusOf(module.url!) ==
          LiveBroadcastStatus.notBroadcasting;

  Widget _buildTile(BuildContext context, {double tint = 0}) {
    final rh = ResponsiveHelper.of(context);
    // Preview-only perk badge: how many unlocked leaf nodes sit inside
    // this folder. Hidden once the user has enrolled (coursePurchasedId
    // != 0) because every node is unlocked then and the count would be
    // meaningless.
    final freeCount = module.isFolder && coursePurchasedId == 0
        ? module.freeContentCount
        : 0;
    return Container(
      margin: EdgeInsets.only(bottom: Screen.getVerticalSize(10)),
      decoration: BoxDecoration(
        color: tint > 0
            ? AppColors.primary.withValues(alpha: 0.08 * tint)
            : null,
        border: Border.all(
          width: 1.5,
          color: tint > 0
              ? AppColors.primary.withValues(alpha: 0.25 + 0.5 * tint)
              : AppColors.mutedTextPrimary.withValues(alpha: 0.25),
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
          // Scheduled release: the node is published but must not open
          // before its start time. Checked here — ahead of every
          // type-specific branch — so it covers images, videos,
          // documents, exams, assignments, zips and folders alike.
          // Live classes are excluded by the getter; their own
          // upcoming/ended handling further down still applies.
          if (module.isScheduleLocked) {
            // A dialog, not a snackbar: the message names the content,
            // a full date, a time and a countdown, which a toast clips.
            ScheduledContentDialog.show(
              context,
              nodeName: module.nodeName,
              startAt: module.startDateTime!,
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
                title: module.isCancelled ? 'Class cancelled' : 'Class ended',
                message: module.isCancelled
                    ? 'This class was cancelled.'
                    : 'This class has ended.',
              );
            } else if (module.isUpcoming) {
              // Joining is blocked until the scheduled start time — the
              // row rebuilds on the 30s tick, so it becomes tappable on
              // its own once the class window opens. Same dialog as the
              // scheduled-file gate, in its live-class wording.
              ScheduledContentDialog.show(
                context,
                nodeName: module.nodeName,
                startAt: module.startDateTime!,
                isLiveClass: true,
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
          child: _getLeading(module, offAir: module.isLiveClass && _offAir),
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
            if (freeCount > 0) ...[
              SizedBox(height: Screen.getVerticalSize(5)),
              Text(
                '$freeCount free access',
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.successDark,
                  fontSize: rh.isLargeScreen
                      ? rh.cappedFontSize(12)
                      : Screen.getFontSize(12),
                ),
              ),
            ],
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

            // Scheduled, not yet released — say so on the row itself so
            // the student understands why it won't open before tapping.
            if (module.isScheduleLocked) ...[
              SizedBox(height: Screen.getVerticalSize(5)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_clock,
                    size: Screen.getSize(12),
                    color: AppColors.mutedTextPrimary,
                  ),
                  SizedBox(width: Screen.getHorizontalSize(4)),
                  Flexible(
                    child: Text(
                      'Unlocks ${_formatStartTime(module.startDateTime!)}',
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                        fontSize: rh.isLargeScreen
                            ? rh.cappedFontSize(12)
                            : Screen.getFontSize(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (module.type == CourseContentType.liveClass) ...[
              SizedBox(height: Screen.getVerticalSize(5)),
              _buildLiveClassSubtitle(rh),
            ],
          ],
        ),
        trailing: _getTrailing(module, offAir: module.isLiveClass && _offAir),
      ),
    );
  }

  /// Coloured status pill for a live-class row, derived from the node's
  /// time state at build time (the row rebuilds on a 30s tick).
  Widget _buildLiveClassSubtitle(ResponsiveHelper rh) {
    final fontSize =
        rh.isLargeScreen ? rh.cappedFontSize(12) : Screen.getFontSize(12);
    if (module.isLiveNow) {
      if (_offAir) {
        return Text(
          module.isPausedByHost ? 'Paused by host' : 'Waiting for host',
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.mutedTextPrimary,
            fontSize: fontSize,
          ),
        );
      }
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
      module.isCancelled
          ? 'Cancelled'
          : (module.isEnded ? 'Ended' : 'Live Class'),
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
    // Include the year once the date leaves the current one, so a
    // schedule set for a later year can't read as a date days away.
    final datePattern = start.year == now.year ? 'd MMM' : 'd MMM yyyy';
    return '${DateFormat(datePattern).format(start)}, $time';
  }
}

/// Rebuilds [builder] every [interval] — used so time-dependent rows
/// (live-class badges) refresh inside a ListView that is built once.
/// [listenable] additionally rebuilds the row the moment it fires, so an
/// async signal (a broadcast-probe verdict) doesn't wait for the tick.
class _PeriodicRebuild extends StatefulWidget {
  final Duration interval;
  final WidgetBuilder builder;
  final Listenable? listenable;

  const _PeriodicRebuild({
    required this.interval,
    required this.builder,
    this.listenable,
  });

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
    widget.listenable?.addListener(_onSignal);
  }

  void _onSignal() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onSignal);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _getLeading(CourseContent module, {bool offAir = false}) {
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
      // Broadcast icon, tinted red only while the class is actually on
      // air and muted once it has ended.
      return Icon(
        Icons.sensors,
        size: Screen.getSize(20),
        color: module.isLiveNow && !offAir
            ? AppColors.error
            : (module.isEnded ? AppColors.mutedTextPrimary : AppColors.primary),
      );
  }
}

Widget? _getTrailing(CourseContent module, {bool offAir = false}) {
  if (module.isLocked) {
    return Image.asset(
      AppImages.passwordIcon,
      width: Screen.getSize(20),
      height: Screen.getSize(20),
      color: AppColors.mutedTextPrimary,
    );
  }
  if (module.isScheduleLocked) {
    // Published but not yet released — a muted clock so the row reads as
    // unavailable at a glance (the tap explains exactly when it opens).
    return Icon(
      Icons.lock_clock,
      size: Screen.getSize(20),
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
    if (offAir) {
      // In the scheduled window but nothing is broadcasting — the host
      // hasn't started, or the class was ended early. The row stays
      // tappable (it opens the waiting room), but a red "Join" pill on
      // a class that isn't on air is a lie.
      return Icon(
        Icons.schedule,
        size: Screen.getSize(20),
        color: AppColors.mutedTextPrimary,
      );
    }
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
