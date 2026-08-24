import 'dart:async';
import 'dart:io';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/assignment/data/models/assignment_model.dart';
import 'package:nexora/features/assignment/presentation/bloc/assignment_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Assignment screen — fetches the assignment for a curriculum node,
/// shows the question content (PDF/image), lets the user submit a
/// single file, and reflects grading once the backend posts a score.
class AssignmentPage extends StatelessWidget {
  /// Assignment row id — carried by the curriculum node's `url` field and
  /// used as the path param on `GET /api/v1/course/{assignmentId}/assignment`.
  final int assignmentId;

  /// Owning course id — still needed for the submit multipart body
  /// (`CourseId` field), which the API requires alongside the assignment id.
  final int courseId;

  /// Curriculum tree node id (the jsonNodeId) — used for completion
  /// tracking and as the submit body's `JsonNodeId`.
  final String nodeId;

  /// Optional — when set, completion is recorded as soon as the
  /// assignment payload finishes loading. Empty / 0 disables tracking
  /// (preview / non-purchased flows).
  final int coursePurchasedId;

  const AssignmentPage({
    super.key,
    required this.assignmentId,
    required this.courseId,
    required this.nodeId,
    this.coursePurchasedId = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<AssignmentCubit>()
            ..load(assignmentId: assignmentId, nodeId: nodeId),
      child: _AssignmentView(
        assignmentId: assignmentId,
        courseId: courseId,
        nodeId: nodeId,
        coursePurchasedId: coursePurchasedId,
      ),
    );
  }
}

class _AssignmentView extends StatefulWidget {
  final int assignmentId;
  final int courseId;
  final String nodeId;
  final int coursePurchasedId;

  const _AssignmentView({
    required this.assignmentId,
    required this.courseId,
    required this.nodeId,
    required this.coursePurchasedId,
  });

  @override
  State<_AssignmentView> createState() => _AssignmentViewState();
}

class _AssignmentViewState extends State<_AssignmentView> {
  /// File the user picked but hasn't submitted yet. Cleared after a
  /// successful submission.
  File? _pickedFile;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _pickedFile = File(path));
  }

  void _submit(Assignment current) {
    final file = _pickedFile;
    if (file == null) {
      CustomSnackbar.error(
        context,
        title: 'No file selected',
        message: 'Pick a file before submitting.',
      );
      return;
    }
    context.read<AssignmentCubit>().submit(
      courseId: widget.courseId,
      nodeId: widget.nodeId,
      current: current,
      file: file,
    );
  }

  /// Fires when the wall clock crosses any window boundary (start or
  /// end). Just triggers a rebuild — `isActive` / `isExpired` derive
  /// from `DateTime.now()` so the parent needs to re-evaluate.
  void _onWindowChanged() {
    if (mounted) setState(() {});
  }

  /// Fires once when the countdown hits zero. Two effects: (1) trigger
  /// a rebuild so the picker can hide itself (the assignment's
  /// `isExpired` flips with the wall clock but parents don't auto-
  /// rebuild on it), and (2) auto-submit the user's picked file if any
  /// — no confirmation dialog since they already chose the file. Works
  /// for both first-time submit and last-second resubmit; the cubit
  /// forwards the existing submissionId so the backend updates in
  /// place when one already exists.
  void _onTimerExpired(Assignment current) {
    if (!mounted) return;
    setState(() {});
    final file = _pickedFile;
    if (file != null) {
      context.read<AssignmentCubit>().submit(
        courseId: widget.courseId,
        nodeId: widget.nodeId,
        current: current,
        file: file,
      );
    }
  }

  /// Confirm-before-submit dialog. Returns synchronously after dispatch
  /// to the cubit so the rest of `_submit`'s flow stays unchanged.
  ///
  /// Copy branches on whether this is a first submit or a resubmit so
  /// the user understands that — while the window is still open — they
  /// can keep replacing their file, and that a resubmit overwrites the
  /// previous one (the cubit forwards the existing submissionId so the
  /// backend updates the row).
  Future<void> _confirmSubmit(Assignment current) async {
    final isResubmit = current.hasSubmission;
    final ok = await _confirm(
      title: isResubmit ? 'Replace your submission?' : 'Submit assignment?',
      message: isResubmit
          ? 'Your previous submission will be overwritten. You can keep '
                'resubmitting until the deadline.'
          : 'You can still resubmit a new file before the deadline.',
      confirmLabel: isResubmit ? 'Replace' : 'Submit',
    );
    if (ok && mounted) _submit(current);
  }

  /// Confirm-before-clear dialog for the picked-file row's X button.
  Future<void> _confirmClearFile() async {
    final ok = await _confirm(
      title: 'Clear selected file?',
      message: 'You\'ll need to pick a file again before you can submit.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (ok && mounted) setState(() => _pickedFile = null);
  }

  /// Generic yes/no AlertDialog used by both confirmation flows.
  /// Resolves to `true` only on explicit confirm.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _openContent(Assignment a) {
    // Content is gated to the active window — peeking the questions
    // before the test starts or after it ends defeats the deadline,
    // so we surface a snackbar instead of opening the viewer.
    if (!a.isActive) {
      if (a.isExpired) {
        CustomSnackbar.error(
          context,
          title: 'Submission window closed',
          message: 'The assignment has ended. Content is no longer available.',
        );
      } else {
        CustomSnackbar.info(
          context,
          title: 'Not started yet',
          message:
              'The assignment content will be available once the test starts.',
        );
      }
      return;
    }
    final url = a.contentUrl;
    if (url == null || url.isEmpty) return;

    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.doc') ||
        path.endsWith('.docx') ||
        path.endsWith('.xls') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.ppt') ||
        path.endsWith('.pptx')) {
      final officeUrl =
          'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(url)}';
      context.push(
        '${AppRoutes.documentViewer}'
        '?title=${Uri.encodeComponent(a.title)}'
        '&url=${Uri.encodeComponent(officeUrl)}',
      );
    } else if (path.endsWith('.pdf') || a.resolvedContentType == 'image') {
      // Both image and PDF nodes route to the PDF viewer — it embeds via
      // the same scaffold and avoids a one-off image-viewer page.
      context.push(
        '${AppRoutes.pdfViewer}'
        '?title=${Uri.encodeComponent(a.title)}'
        '&url=${Uri.encodeComponent(url)}',
        extra: {'showActions': false},
      );
    } else {
      if (url.toLowerCase().startsWith('http')) {
        context.push(
          '${AppRoutes.documentViewer}'
          '?title=${Uri.encodeComponent(a.title)}'
          '&url=${Uri.encodeComponent(url)}',
        );
      } else {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    final rh = ResponsiveHelper.of(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      // AppBar mirrors the PDF viewer: dark navy chrome with a white
      // centred title (and chevron, since CustomAppBar tints the back
      // button from titleColor).
      appBar: CustomAppBar(
        title: 'Assignment Details',
        centerTitle: true,
        titleColor: AppColors.white,
        backgroundColor: AppColors.videoPlayerBgColor,
        titleStyle: AppTypography.h6SemiBold.copyWith(
          color: AppColors.alwaysWhite,
          fontSize: rh.isLargeScreen ? Screen.getFontSize(20) / 1.5 : null,
        ),
      ),
      body: BlocConsumer<AssignmentCubit, AssignmentState>(
        listener: (context, state) {
          state.maybeWhen(
            // Assignment nodes record completion as soon as the content
            // loads, and again on a successful submit. Both fire because
            // neither on its own is un-skippable: a student may open and
            // never submit, and a submit may be the first state we see
            // after a restore. The service dedups, so it's one POST.
            loaded: (_) {
              sl<ContentCompletionService>().markCompleted(
                coursePurchasedId: widget.coursePurchasedId,
                jsonContentId: widget.nodeId,
              );
            },
            submitted: (_) {
              sl<ContentCompletionService>().markCompleted(
                coursePurchasedId: widget.coursePurchasedId,
                jsonContentId: widget.nodeId,
              );
              setState(() => _pickedFile = null);
              CustomSnackbar.success(
                context,
                title: 'Submitted',
                message: 'Your assignment has been submitted for grading.',
              );
            },
            error: (message) =>
                CustomSnackbar.error(context, title: 'Error', message: message),
            orElse: () {},
          );
        },
        builder: (context, state) {
          final rh = ResponsiveHelper.of(context);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(rh.fontScaleFactor)),
            child: state.maybeWhen(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (message) => _ErrorView(
                message: message,
                onRetry: () => context.read<AssignmentCubit>().load(
                  assignmentId: widget.assignmentId,
                  nodeId: widget.nodeId,
                ),
              ),
              loaded: (a) => _Body(
                assignment: a,
                isSubmitting: false,
                pickedFile: _pickedFile,
                onPick: _pickFile,
                onSubmit: () => _confirmSubmit(a),
                onClearFile: _confirmClearFile,
                onExpired: () => _onTimerExpired(a),
                onStarted: _onWindowChanged,
                onOpenContent: () => _openContent(a),
              ),
              submitting: (a) => _Body(
                assignment: a,
                isSubmitting: true,
                pickedFile: _pickedFile,
                onPick: _pickFile,
                onSubmit: () => _confirmSubmit(a),
                onClearFile: _confirmClearFile,
                onExpired: () => _onTimerExpired(a),
                onStarted: _onWindowChanged,
                onOpenContent: () => _openContent(a),
              ),
              submitted: (a) => _Body(
                assignment: a,
                isSubmitting: false,
                pickedFile: _pickedFile,
                onPick: _pickFile,
                onSubmit: () => _confirmSubmit(a),
                onClearFile: _confirmClearFile,
                onExpired: () => _onTimerExpired(a),
                onStarted: _onWindowChanged,
                onOpenContent: () => _openContent(a),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Body — the whole scrollable section + sticky bottom CTA.
// ─────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final Assignment assignment;
  final bool isSubmitting;
  final File? pickedFile;
  final VoidCallback onPick;
  final VoidCallback onSubmit;
  final VoidCallback onClearFile;
  final VoidCallback onExpired;
  final VoidCallback onStarted;
  final VoidCallback onOpenContent;

  const _Body({
    required this.assignment,
    required this.isSubmitting,
    required this.pickedFile,
    required this.onPick,
    required this.onSubmit,
    required this.onClearFile,
    required this.onExpired,
    required this.onStarted,
    required this.onOpenContent,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: rh.isLargeScreen
                  ? rh.horizontalPadding
                  : Screen.getHorizontalSize(15),
              vertical: Screen.getVerticalSize(12),
            ),
            children: [
              _AssignmentTitle(title: assignment.title),
              SizedBox(height: Screen.getVerticalSize(20)),

              // Submission card lives in the scroll area whenever the
              // user has an existing submission — the sticky bottom
              // shows the result banner (awaiting / evaluated) so the
              // user can see their file without scrolling all the way
              // down.
              if (assignment.hasSubmission) ...[
                _YourSubmissionCard(
                  assignment: assignment,
                  pickedFile: pickedFile,
                ),
                SizedBox(height: Screen.getVerticalSize(20)),
              ],

              _RequirementsSection(assignment: assignment),
              SizedBox(height: Screen.getVerticalSize(20)),

              _TimelineSection(assignment: assignment),

              if (assignment.description.isNotEmpty) ...[
                SizedBox(height: Screen.getVerticalSize(15)),
                InstructionsBlock(text: assignment.description),
              ],

              SizedBox(height: Screen.getVerticalSize(20)),
              _ContentHero(assignment: assignment, onTap: onOpenContent),
              SizedBox(height: Screen.getVerticalSize(24)),
            ],
          ),
        ),
        // Sticky bottom bar: timer + file-picker / submission-card /
        // banner stack the user is currently acting on, with the submit
        // CTA pinned directly beneath. Moving the middle-state section
        // here keeps the user's submission affordances together at
        // thumb height rather than buried in the scroll.
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rh.isLargeScreen
                  ? rh.horizontalPadding
                  : Screen.getHorizontalSize(16),
              vertical: Screen.getVerticalSize(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiddleStateSection(
                  assignment: assignment,
                  pickedFile: pickedFile,
                  isSubmitting: isSubmitting,
                  onPick: onPick,
                  onClearFile: onClearFile,
                  onExpired: onExpired,
                  onStarted: onStarted,
                ),
                // Submit only renders when there's something to submit
                // (a picked file) or a submission is mid-flight — so the
                // button stays out of the way until the user actually
                // has work for it to do.
                if (isSubmitting || pickedFile != null) ...[
                  SizedBox(height: Screen.getVerticalSize(12)),
                  _ActionButton(
                    assignment: assignment,
                    isSubmitting: isSubmitting,
                    hasPickedFile: pickedFile != null,
                    onSubmit: onSubmit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero — lavender backdrop + tappable "View Assignment Content" tile.
// ─────────────────────────────────────────────────────────────────────
class _ContentHero extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;

  const _ContentHero({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasContent =
        assignment.contentUrl != null && assignment.contentUrl!.isNotEmpty;
    final isImage = assignment.resolvedContentType == 'image';

    return Container(
      width: double.infinity,
      padding: Screen.getPadding(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Column(
        children: [
          Container(
            width: Screen.getSize(76),
            height: Screen.getSize(76),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            // Image preview if asset is an image and small enough; falls
            // back to a doc-ish glyph for PDFs (matches the spec).
            child: isImage && hasContent
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    child: CustomNetworkImage(
                      url: assignment.contentUrl!,
                      width: Screen.getSize(60),
                      height: Screen.getSize(60),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.description_rounded,
                    size: Screen.getSize(36),
                    color: AppColors.primary,
                  ),
          ),
          SizedBox(height: Screen.getVerticalSize(16)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasContent ? onTap : null,
            child: Text(
              hasContent
                  ? 'View Assignment Content'
                  : 'No content uploaded yet',
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: hasContent
                    ? AppColors.primary
                    : AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Title — large heading. Falls back to "Assignment" if the backend
// ships an empty title.
// ─────────────────────────────────────────────────────────────────────
class _AssignmentTitle extends StatelessWidget {
  final String title;

  const _AssignmentTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.isEmpty ? 'Assignment' : title,
      style: AppTypography.h6SemiBold.copyWith(
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header — bold, uppercase, letter-spaced label that sits above
// every grouping in the body (REQUIREMENTS / TIMELINE / …).
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.bodyTextMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Requirements — three side-by-side tiles for total marks, passing
// marks, and duration. Missing fields fall through to "—" so the row
// keeps its shape regardless of which numbers the backend ships.
// ─────────────────────────────────────────────────────────────────────
class _RequirementsSection extends StatelessWidget {
  final Assignment assignment;

  const _RequirementsSection({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('REQUIREMENTS'),
        SizedBox(height: Screen.getVerticalSize(12)),
        Row(
          children: [
            Expanded(
              child: _RequirementTile(
                icon: Icons.stars_rounded,
                label: 'Total',
                value: assignment.totalMarks != null
                    ? _fmt(assignment.totalMarks!)
                    : '-',
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(10)),
            Expanded(
              child: _RequirementTile(
                icon: Icons.verified_rounded,
                label: 'Passing',
                value: assignment.passingMarks != null
                    ? _fmt(assignment.passingMarks!)
                    : '-',
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(10)),
            Expanded(
              child: _RequirementTile(
                icon: Icons.timer_outlined,
                label: 'Time',
                value: assignment.durationMinutes != null
                    ? '${assignment.durationMinutes}m'
                    : '-',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequirementTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RequirementTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: Screen.getPadding(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          // Lavender wash — primary tint at low alpha so the tile reads
          // as accent-coloured without being saturated.
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        // FittedBox keeps the icon + label + value stack inside the
        // 1:1 box on every screen width — without it the intrinsic
        // height overflows by ~4 px on narrower devices.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: Screen.getSize(28)),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                label,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(4)),
              Text(
                value,
                style: AppTypography.h5SemiBold.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: rh.isLargeScreen ? rh.cappedFontSize(32) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Timeline — flat (no card chrome) Start Time / Due Date timeline. A
// thin grey rule connects the two dot rings, with the labels and
// values left-aligned to the right of each dot. Missing dates fall
// through to "—".
// ─────────────────────────────────────────────────────────────────────
class _TimelineSection extends StatelessWidget {
  final Assignment assignment;

  const _TimelineSection({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('TIMELINE'),
        SizedBox(height: Screen.getVerticalSize(10)),
        _TimelineRow(
          dotColor: AppColors.primary,
          label: 'START DATE & TIME',
          time: assignment.startTime,
          isLast: false,
        ),
        _TimelineRow(
          dotColor: AppColors.textPrimary,
          label: 'DUE DATE & TIME',
          time: assignment.endTime,
          isLast: true,
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final DateTime? time;
  final bool isLast;

  const _TimelineRow({
    required this.dotColor,
    required this.label,
    required this.time,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot column — dot on top, vertical connector below until the
          // next dot. The connector lives only on non-last rows, so the
          // line stops at the bottom dot.
          Column(
            children: [
              _TimelineDot(color: dotColor),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: AppColors.mutedTextPrimary.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          SizedBox(width: Screen.getHorizontalSize(15)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                // Pad so the bottom row gets the same breathing room
                // the connector gives the top row.
                bottom: isLast ? 0 : Screen.getVerticalSize(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.mutedTextPrimary,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(5)),
                  Text(
                    time == null ? '-' : _formatTimelineDateTime(time!),
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outer cream ring + solid colour core — matches the Figma timeline
/// markers (start uses primary blue, due uses black).
class _TimelineDot extends StatelessWidget {
  final Color color;

  const _TimelineDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // color: AppColors.warning.withValues(alpha: 0.25),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// "Oct 12, 2024 • 09:00 AM" — combines a short date with a 12-hour
/// time, separated by a middle dot.
String _formatTimelineDateTime(DateTime t) =>
    '${DateFormat('MMM d, y').format(t)} • ${DateFormat('hh:mm a').format(t)}';

// ─────────────────────────────────────────────────────────────────────
// Instructions — bordered card with a collapsible body. The body is
// clipped to three lines initially; if the text actually overflows we
// surface a "Read More" / "Read Less" toggle in the primary tint.
// ─────────────────────────────────────────────────────────────────────
class InstructionsBlock extends StatefulWidget {
  final String text;

  const InstructionsBlock({super.key, required this.text});

  @override
  State<InstructionsBlock> createState() => InstructionsBlockState();
}

class InstructionsBlockState extends State<InstructionsBlock> {
  static const int _collapsedMaxLines = 3;
  bool _expanded = false;

  /// Measures the body text against [maxWidth] to decide whether it
  /// would overflow [_collapsedMaxLines]. Without this check, short
  /// notes that already fit would still show a useless toggle.
  ///
  /// `intl` exports its own `TextDirection` that shadows Flutter's
  /// dart:ui one in this file's import set, so we pull the direction
  /// from the ambient [Directionality] instead of using the constant.
  bool _overflowsAt(double maxWidth, TextStyle style, BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: _collapsedMaxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTypography.bodyTextMedium.copyWith(
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary.withValues(alpha: 0.75),
    );
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border(
          right: BorderSide(color: AppColors.primary, width: 0.75),
          top: BorderSide(color: AppColors.primary, width: 0.75),
          bottom: BorderSide(color: AppColors.primary, width: 0.75),
          left: BorderSide(color: AppColors.primary, width: 5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflows = _overflowsAt(
            constraints.maxWidth,
            bodyStyle,
            context,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Instructions',
                style: AppTypography.h6SemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: Screen.getVerticalSize(10)),
              Text(
                widget.text,
                style: bodyStyle,
                maxLines: _expanded ? null : _collapsedMaxLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (overflows) ...[
                SizedBox(height: Screen.getVerticalSize(10)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Read Less' : 'Read More',
                    style: AppTypography.bodyTextSemiBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Middle state section: submission card / picker / not-attended banner.
// ─────────────────────────────────────────────────────────────────────
class _MiddleStateSection extends StatelessWidget {
  final Assignment assignment;
  final File? pickedFile;

  /// Whether a submission is currently in flight. While true we skip
  /// the `didNotAttend` short-circuit so the user keeps seeing the
  /// timer + file row instead of an "expired" banner during the upload
  /// the auto-submit triggered on timer expiry.
  final bool isSubmitting;
  final VoidCallback onPick;
  final VoidCallback onClearFile;
  final VoidCallback onExpired;
  final VoidCallback onStarted;

  const _MiddleStateSection({
    required this.assignment,
    required this.pickedFile,
    required this.isSubmitting,
    required this.onPick,
    required this.onClearFile,
    required this.onExpired,
    required this.onStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSubmitting && assignment.didNotAttend) {
      return _NotAttendedBanner();
    }
    // Final-state banners only when the user can no longer act:
    //   * Graded → Evaluation Complete (terminal).
    //   * Submitted + window closed → Awaiting Evaluation banner.
    // While the window is still active, hasSubmission alone is NOT a
    // terminal state — the user can keep picking new files and
    // resubmitting (the cubit sends the existing submissionId so the
    // backend updates the row instead of creating a duplicate).
    if (assignment.hasGrade) {
      return _EvaluationCompleteBanner(assignment: assignment);
    }
    if (assignment.hasSubmission && assignment.isExpired) {
      return _SuccessfullySubmittedBanner();
    }
    if (!assignment.isActive && !assignment.isExpired) {
      // Upcoming — show a countdown to the test start + a locked
      // placeholder where the picker would go. The banner fires
      // `onStarted` when the wall clock crosses startTime so the
      // parent can rebuild into the active branch.
      return _UpcomingBanner(
        startTime: assignment.startTime,
        onStarted: onStarted,
      );
    }
    // Active window (or submitting after expiry). Timer always shows
    // when there's an endTime; the picker hides once expired so the
    // user can't queue a file too late, and the picked-file row
    // replaces the picker as soon as a file is chosen.
    final endTime = assignment.endTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (endTime != null) ...[
          _TimeRemainingTimer(endTime: endTime, onExpired: onExpired),
          SizedBox(height: Screen.getVerticalSize(12)),
        ],
        if (pickedFile != null)
          _PickedFileRow(
            file: pickedFile!,
            onClear: isSubmitting ? null : onClearFile,
          )
        else if (!assignment.isExpired)
          _FilePickerCard(onPick: onPick),
      ],
    );
  }
}

/// Compact filename pill with a trailing X that triggers the clear
/// confirmation. Shown in place of the upload drop-zone once the user
/// has picked a file.
class _PickedFileRow extends StatelessWidget {
  final File file;
  final VoidCallback? onClear;

  const _PickedFileRow({required this.file, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final filename = file.uri.pathSegments.last;
    return Container(
      padding: Screen.getPadding(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: AppColors.primary,
            size: Screen.getSize(22),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          // No clear button while submitting — the file is in flight.
          if (onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: Screen.getPadding(all: 4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.mutedTextPrimary,
                  size: Screen.getSize(20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Countdown — header row with an alert icon + "Time Remaining" label on
// the left, a tinted pill with HH:MM:SS digits on the right. Ticks
// every second; flips to an "Expired" pill at zero so the submit
// button can take over the "what happened" copy.
// ─────────────────────────────────────────────────────────────────────
class _TimeRemainingTimer extends StatefulWidget {
  final DateTime endTime;

  /// Fired exactly once when the countdown hits zero. The caller uses
  /// it to (a) re-render the parent so the picker hides, and (b)
  /// auto-submit any file the user already picked.
  final VoidCallback? onExpired;

  const _TimeRemainingTimer({required this.endTime, this.onExpired});

  @override
  State<_TimeRemainingTimer> createState() => _TimeRemainingTimerState();
}

class _TimeRemainingTimerState extends State<_TimeRemainingTimer> {
  Timer? _ticker;
  late Duration _remaining;
  bool _didFireExpired = false;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    if (_remaining == Duration.zero) {
      // Already expired on mount — schedule the callback for the next
      // frame so the parent's setState during build is well-defined.
      _didFireExpired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired?.call();
      });
    }
    // Tick every second. Once expired we cancel ourselves so we don't
    // keep rebuilding for nothing.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _computeRemaining();
      setState(() => _remaining = next);
      if (next == Duration.zero) {
        _ticker?.cancel();
        if (!_didFireExpired) {
          _didFireExpired = true;
          widget.onExpired?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _computeRemaining() {
    final diff = widget.endTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// "00:44:43" — HH:MM:SS, all segments zero-padded. Hours cap at 99
  /// so a runaway timer doesn't blow up the layout.
  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours.clamp(0, 99);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: Screen.getSize(18),
        ),
        SizedBox(width: Screen.getHorizontalSize(6)),
        Expanded(
          child: Text(
            expired ? 'Time\'s up' : 'Time Remaining',
            style: AppTypography.bodyTextLargeMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
        Container(
          padding: Screen.getPadding(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.errorBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          child: Text(
            expired ? '00:00:00' : _format(_remaining),
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: AppColors.error,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the user's uploaded submission file in the shared PDF viewer
/// route. Images and PDFs both render through that viewer (same pattern
/// as [_AssignmentViewState._openContent] for the question paper).
void _openSubmission(BuildContext context, String url, String assignmentTitle) {
  final title = assignmentTitle.isEmpty
      ? 'Submission'
      : '$assignmentTitle Submission';
  context.push(
    '${AppRoutes.pdfViewer}'
    '?title=${Uri.encodeComponent(title)}'
    '&url=${Uri.encodeComponent(url)}',
    extra: {'showActions': false},
  );
}

class _YourSubmissionCard extends StatelessWidget {
  final Assignment assignment;
  final File? pickedFile;

  const _YourSubmissionCard({
    required this.assignment,
    required this.pickedFile,
  });

  @override
  Widget build(BuildContext context) {
    final url = assignment.submissionFileUrl;
    final hasRemoteFile = pickedFile == null && url != null && url.isNotEmpty;
    final filename = pickedFile != null
        ? pickedFile!.uri.pathSegments.last
        : (url != null && url.isNotEmpty)
        ? Uri.tryParse(url)?.pathSegments.last ?? 'submission file'
        : 'submission file';

    return Container(
      width: double.infinity,
      padding: Screen.getPadding(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.successDark,
                size: Screen.getSize(20),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                'Your Submission',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Only tappable when there's an actual hosted submission to
              // open — a locally-picked-but-not-yet-uploaded file has no
              // remote URL and "New file picked — submit to upload" is
              // the right message there.
              onTap: hasRemoteFile
                  ? () => _openSubmission(context, url, assignment.title)
                  : null,
              child: Padding(
                padding: Screen.getPadding(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_rounded,
                      size: Screen.getSize(28),
                      color: AppColors.successDark,
                    ),
                    SizedBox(width: Screen.getHorizontalSize(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: Screen.getVerticalSize(2)),
                          Text(
                            pickedFile != null
                                ? 'New file picked. Submit to upload'
                                : 'Tap to view uploaded file',
                            style: AppTypography.bodyTextMedium.copyWith(
                              color: AppColors.mutedTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasRemoteFile)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: Screen.getSize(22),
                        color: AppColors.mutedTextPrimary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Grade row — embedded inside the submission card once the
          // backend ships a grade. Divider above so it reads as a
          // separate section but stays visually anchored to the file.
          if (assignment.hasGrade) ...[
            SizedBox(height: Screen.getVerticalSize(14)),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.success.withValues(alpha: 0.25),
            ),
            SizedBox(height: Screen.getVerticalSize(14)),
            _FinalGradeRow(assignment: assignment),
          ],
        ],
      ),
    );
  }
}

/// "Final Grade:    85 / 100" — bold score on the right, muted label
/// on the left. Sits inside [_YourSubmissionCard] only when a grade
/// has actually landed.
class _FinalGradeRow extends StatelessWidget {
  final Assignment assignment;

  const _FinalGradeRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final grade = assignment.grade!;
    final total = assignment.totalMarks;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Final Grade:',
          style: AppTypography.bodyTextLargeMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _fmt(grade),
                // Headline tone for the score — heavy weight + larger
                // size so it reads as the result, not a label.
                style: AppTypography.h5SemiBold.copyWith(
                  color: AppColors.successDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (total != null)
                TextSpan(
                  text: ' / ${_fmt(total)}',
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sticky-bottom banner shown once a grade has landed. The score lives
/// inside [_YourSubmissionCard]'s embedded grade row, so this is
/// intentionally a quiet, disabled-looking pill that reads as a "closed"
/// state — same neutral weight as the "Locked" pill on the upcoming
/// screen.
class _EvaluationCompleteBanner extends StatelessWidget {
  final Assignment assignment;

  const _EvaluationCompleteBanner({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      alignment: Alignment.center,
      child: Text(
        'Evaluation Complete',
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Sticky-bottom banner shown once the user has submitted but a grade
/// hasn't landed yet. Mirrors the "Not Attempted" banner pattern — pill
/// + a muted helper line — but in success green.
class _SuccessfullySubmittedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: Screen.getPadding(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_rounded,
                color: AppColors.successDark,
                size: Screen.getSize(20),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                'Successfully Submitted',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(8)),
        Text(
          'You cannot edit your submission.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.mutedTextPrimary,
          ),
        ),
      ],
    );
  }
}

/// Dashed rounded rectangle — cloud-upload glyph + "Upload Answer
/// Sheet" label, centred. Only rendered before the user picks a file;
/// once a file is selected the parent swaps it out for [_PickedFileRow].
class _FilePickerCard extends StatelessWidget {
  final VoidCallback onPick;

  const _FilePickerCard({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(AppSizes.radiusL);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPick,
      child: CustomPaint(
        painter: _DashedRoundedRectPainter(
          color: AppColors.primary.withValues(alpha: 0.4),
          strokeWidth: 1.2,
          dashLength: 6,
          gapLength: 4,
          radius: radius,
        ),
        child: Container(
          width: double.infinity,
          padding: Screen.getPadding(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.all(radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.primary,
                size: Screen.getSize(28),
              ),
              SizedBox(height: Screen.getVerticalSize(8)),
              Text(
                'Upload Answer Sheet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle stroke around the child. Used by
/// the file-picker card to match the Figma's "drop zone" look since
/// Flutter doesn't ship a dashed BorderSide.
class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final Radius radius;

  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gapLength;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.radius != radius;
}

/// Upcoming-test state — "Starts in HH:MM:SS" countdown on top, a
/// disabled-looking "Locked" pill underneath where the picker would
/// normally sit. Fires [onStarted] exactly once when the wall clock
/// reaches [startTime] so the parent can swap into the active branch.
class _UpcomingBanner extends StatefulWidget {
  final DateTime? startTime;
  final VoidCallback? onStarted;

  const _UpcomingBanner({required this.startTime, this.onStarted});

  @override
  State<_UpcomingBanner> createState() => _UpcomingBannerState();
}

class _UpcomingBannerState extends State<_UpcomingBanner> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _didFireStarted = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    if (widget.startTime == null) return;
    if (_remaining == Duration.zero) {
      // Already started by the time we mount — schedule the callback
      // on the next frame to keep state mutations out of build.
      _didFireStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStarted?.call();
      });
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _compute();
      setState(() => _remaining = next);
      if (next == Duration.zero) {
        _ticker?.cancel();
        if (!_didFireStarted) {
          _didFireStarted = true;
          widget.onStarted?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _compute() {
    final t = widget.startTime;
    if (t == null) return Duration.zero;
    final diff = t.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// "02:04:18" — HH:MM:SS, zero-padded. Hours cap at 99 so a runaway
  /// countdown doesn't blow up the layout.
  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours.clamp(0, 99);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasStart = widget.startTime != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasStart)
          Row(
            children: [
              Text(
                'Starts in',
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: Screen.getPadding(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  _format(_remaining),
                  style: AppTypography.bodyTextLargeSemiBold.copyWith(
                    color: AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        if (hasStart) SizedBox(height: Screen.getVerticalSize(12)),
        // Disabled-looking "Locked" pill that occupies the same slot the
        // picker would take once the test starts.
        Container(
          width: double.infinity,
          padding: Screen.getPadding(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.mutedTextPrimary,
                size: Screen.getSize(20),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                'Locked',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotAttendedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill: icon + "Not Attempted" label on a light error wash. The
        // pill is the visual primary; the line below explains why.
        Container(
          width: double.infinity,
          padding: Screen.getPadding(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.errorBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: Screen.getSize(20),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                'Not Attempted',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(8)),
        Text(
          'Deadline has passed. Submissions are closed.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.mutedTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bottom CTA — label and enabled-ness driven entirely by assignment +
// submission state. The host file's _submit() handles the actual call.
// ─────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final Assignment assignment;
  final bool isSubmitting;
  final bool hasPickedFile;
  final VoidCallback onSubmit;

  const _ActionButton({
    required this.assignment,
    required this.isSubmitting,
    required this.hasPickedFile,
    required this.onSubmit,
  });

  /// Resolves what label + enabled state the button should expose for
  /// every combination of (window, submission, grade, picked file,
  /// submitting). Centralised so the visual is consistent and the
  /// branching is readable.
  ({String label, bool enabled, bool tonal}) _resolve() {
    if (isSubmitting) {
      return (label: 'Submitting…', enabled: false, tonal: false);
    }
    if (assignment.hasGrade) {
      return (label: 'Evaluation Complete', enabled: false, tonal: true);
    }
    if (assignment.didNotAttend) {
      return (label: 'Did not attend', enabled: false, tonal: true);
    }
    if (assignment.isExpired) {
      return assignment.hasSubmission
          ? (label: 'Awaiting Evaluation', enabled: false, tonal: true)
          : (label: 'Window Closed', enabled: false, tonal: true);
    }
    if (!assignment.isActive) {
      return (label: 'Not Yet Open', enabled: false, tonal: true);
    }
    // Active window.
    if (assignment.hasSubmission) {
      return (
        label: hasPickedFile ? 'Resubmit' : 'Pick a file to resubmit',
        enabled: hasPickedFile,
        tonal: !hasPickedFile,
      );
    }
    return (
      label: hasPickedFile ? 'Submit Assignment' : 'Pick a file to submit',
      enabled: hasPickedFile,
      tonal: !hasPickedFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolve();
    final bg = r.tonal ? AppColors.grey100 : AppColors.primary;
    final fg = r.tonal ? AppColors.textPrimary : AppColors.white;

    return SizedBox(
      width: double.infinity,
      height: Screen.getVerticalSize(54),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: r.enabled ? onSubmit : null,
          child: Center(
            child: Text(
              r.label,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Strip trailing `.0` for whole numbers (`100.0` → `100`).
String _fmt(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
