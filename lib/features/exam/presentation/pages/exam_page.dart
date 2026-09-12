import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/exam/domain/entities/exam_context.dart';
import 'package:nexora/features/exam/presentation/bloc/exam_cubit.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_calculator.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_competitive_view.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_countdown.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_history_sheet.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_intro_view.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_leaderboard_sheet.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_paper_view.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_result_view.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_section_transition_view.dart';

/// Host screen for the exam-taking flow. Opened from an `exam` curriculum
/// node. Owns the [ExamCubit] and renders the right sub-view per state.
class ExamPage extends StatelessWidget {
  /// Exam id (carried by the curriculum node's `url` field).
  final int examId;

  /// Curriculum tree node id — used for completion tracking.
  final String nodeId;

  /// Owning course id. Sent with the attempt so the educator's Stats page can
  /// filter results by course.
  final int courseId;

  /// Folder trail this exam node sits under, e.g. "Module 1 › Chapter 2".
  /// Descriptive only — [nodeId] is what scopes the attempt.
  final String folderPath;

  /// When non-zero, the node is marked complete on open (purchased flow).
  final int coursePurchasedId;

  const ExamPage({
    super.key,
    required this.examId,
    required this.nodeId,
    required this.courseId,
    this.folderPath = '',
    this.coursePurchasedId = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExamCubit>(
      create: (_) {
        // Opening an exam node counts as consuming it (parity with
        // image/zip nodes which fire completion on load). No-ops when
        // coursePurchasedId is 0.
        _markCompleted();
        // The context is what makes this placement's attempts its own: the
        // same exam in another course (or another folder) now has a separate
        // run of attempts instead of reporting "already submitted" here.
        return sl<ExamCubit>()..open(
          examId,
          context: ExamContext(
            nodeId: nodeId,
            courseId: courseId,
            folderPath: folderPath.isEmpty ? null : folderPath,
          ),
        );
      },
      // Second trigger on the attempt actually starting. The open-time
      // call above already covers the common path, but this guarantees a
      // student who reaches the paper is recorded even if the first POST
      // was made before the node ids were resolvable. The service dedups,
      // so the two triggers collapse into one request.
      child: BlocListener<ExamCubit, ExamState>(
        listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
        listener: (context, state) {
          final started = state.maybeWhen(
            taking: (_, __, ___, ____, _____) => true,
            competitiveQuestion: (_, __, ___, ____) => true,
            sectionTransition: (_, __, ___, ____) => true,
            orElse: () => false,
          );
          if (started) _markCompleted();
        },
        child: const _ExamView(),
      ),
    );
  }

  void _markCompleted() {
    sl<ContentCompletionService>().markCompleted(
      coursePurchasedId: coursePurchasedId,
      jsonContentId: nodeId,
    );
  }
}

class _ExamView extends StatefulWidget {
  const _ExamView();

  @override
  State<_ExamView> createState() => _ExamViewState();
}

class _ExamViewState extends State<_ExamView> {
  /// Last calculator setting seen on a state that carries it.
  ///
  /// Only the paper and the competitive question responses carry the
  /// flags; the section-transition screen in between does not. Remembering
  /// them keeps the panel mounted across that gap, so a student who was
  /// mid-calculation doesn't come back to a reset calculator parked in a
  /// different corner.
  bool _calculatorAllowed = false;
  ExamCalculatorType _calculatorType = ExamCalculatorType.simple;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamCubit, ExamState>(
      builder: (context, state) {
        final cubit = context.read<ExamCubit>();
        // Any "in the middle of the exam" state where an accidental back
        // should be guarded.
        final isTaking = state.maybeWhen(
          taking: (_, __, ___, ____, _____) => true,
          competitiveQuestion: (_, __, ___, ____) => true,
          sectionTransition: (_, __, ___, ____) => true,
          orElse: () => false,
        );

        // Read from the response being rendered rather than a cached copy
        // — an admin can flip the setting mid-attempt, and competitive
        // mode re-fetches it with every question. Assigned during build
        // (no setState) because it is consumed by this same build.
        state.maybeWhen(
          taking: (paper, _, __, ___, ____) {
            _calculatorAllowed = paper.allowCalculator;
            _calculatorType = paper.calculatorType;
          },
          competitiveQuestion: (data, _, __, ___) {
            _calculatorAllowed = data.allowCalculator;
            _calculatorType = data.calculatorType;
          },
          orElse: () {},
        );
        // The paper is closed once grading starts; the calculator goes
        // with it rather than floating over the result screen.
        final showCalculator = _calculatorAllowed && isTaking;

        return PopScope(
          canPop: !isTaking,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !isTaking) return;
            await _handleBack(context, cubit);
          },
          child: Scaffold(
            backgroundColor: AppColors.scaffoldLight,
            appBar: CustomAppBar(
              title: state.maybeWhen(
                gate: (g) => g.examTitle,
                taking: (paper, _, __, ___, ____) => paper.examTitle,
                competitiveQuestion: (data, _, __, ___) => data.examTitle,
                result: (r) => r.examTitle,
                orElse: () => 'Exam',
              ),
              centerTitle: false,
              backgroundColor: AppColors.white,
              titleColor: AppColors.textPrimary,
              onBackPressed: () async {
                if (isTaking) {
                  await _handleBack(context, cubit);
                } else {
                  context.pop();
                }
              },
              actions: [
                // Rankings for this exam placement. Only on the result
                // screen — before that the student has no score to compare,
                // and mid-exam it would be a way out of the paper.
                () {
                  final onResult = state.maybeWhen(
                    result: (_) => true,
                    orElse: () => false,
                  );
                  if (!onResult) return const SizedBox.shrink();
                  // A bare icon on a white app bar reads as decoration, so
                  // this is tinted, outlined and named: filled in the primary
                  // colour with its own label, which is what makes a student
                  // recognise it as something to tap rather than a badge.
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: 10,
                    ),
                    child: Material(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusCircle,
                      ),
                      child: InkWell(
                        onTap: () =>
                            showExamLeaderboardSheet(context, cubit: cubit),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusCircle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusCircle,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.leaderboard_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Rankings',
                                style: AppTypography.bodyTextXtraSmallSemiBold
                                    .copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
                () {
                  final deadline = state.maybeWhen(
                    taking: (_, __, d, ___, ____) => d,
                    competitiveQuestion: (_, __, d, ___) => d,
                    sectionTransition: (_, __, d, ___) => d,
                    orElse: () => null,
                  );
                  if (deadline == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSizes.paddingM),
                    child: Center(
                      child: ExamCountdown(
                        deadlineUtc: deadline,
                        onExpired: () => cubit.submit(autoSubmitted: true),
                      ),
                    ),
                  );
                }(),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Stack(
                children: [
                  Positioned.fill(child: _body(context, state, cubit)),
                  // Last child, so it floats above the paper. It keeps its
                  // slot in this Stack across every rebuild, which is what
                  // preserves its position, size and expression while the
                  // student types answers underneath it.
                  if (showCalculator)
                    Positioned.fill(
                      child: ExamCalculator(type: _calculatorType),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ExamState state, ExamCubit cubit) {
    return state.when(
      initial: () => const _Busy(),
      loading: () => const _Busy(),
      gate: (gate) => ExamIntroView(
        gate: gate,
        onStart: cubit.startOrResume,
        onReattempt: cubit.reattempt,
        onViewResult: cubit.viewResult,
        onOpenHistory: () => showExamHistorySheet(context, cubit: cubit),
      ),
      notSupported: (reason) => _Message(
        icon: Icons.devices_other,
        title: 'Not available in the app',
        message: reason,
      ),
      taking: (paper, answers, deadline, stopped, pinned) => ExamPaperView(
        paper: paper,
        answers: answers,
        autosaveStopped: stopped,
        pinnedQuestionIds: pinned,
        onUpdateAnswer: cubit.updateAnswer,
        onTogglePin: cubit.togglePin,
        onClearPins: cubit.clearPins,
        onSubmit: () => cubit.submit(autoSubmitted: false),
      ),
      competitiveQuestion: (data, draft, deadline, submitting) =>
          ExamCompetitiveView(
            data: data,
            draft: draft,
            submitting: submitting,
            onAnswerChanged: cubit.updateCompetitiveAnswer,
            onSaveNext: cubit.answerCurrent,
          ),
      sectionTransition: (from, next, deadline, loading) =>
          ExamSectionTransitionView(
            fromSectionName: from,
            nextSectionName: next,
            loading: loading,
            onContinue: cubit.continueToNextSection,
          ),
      submitting: () => const _Busy(label: 'Grading your answers…'),
      result: (result) => ExamResultView(
        result: result,
        onReattempt: cubit.reattempt,
        onOpenHistory: () => showExamHistorySheet(context, cubit: cubit),
      ),
      error: (message) => _Message(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: message,
        onRetry: cubit.refreshGate,
      ),
    );
  }

  /// The single way out of a running exam, shared by the back gesture and the
  /// app-bar button.
  ///
  /// A student gets [ExamCubit.maxExits] exits per attempt. Spending the last
  /// one is still a normal exit; it is the NEXT back press that submits, so
  /// nobody is graded by the same press that used up their allowance.
  Future<void> _handleBack(BuildContext context, ExamCubit cubit) async {
    final remaining = await cubit.exitsRemaining();
    if (!context.mounted) return;

    if (remaining <= 0) {
      // Submitted before the notice, not after: an acknowledge button the
      // student can sit on would make "automatic" theirs to postpone.
      await cubit.submit(autoSubmitted: true);
      if (!context.mounted) return;
      await _showExitLimitNotice(context);
      return;
    }

    final leave = await _confirmLeave(context, remaining: remaining);
    if (leave != true || !context.mounted) return;
    // Recorded only now — a cancelled dialog means they stayed put.
    await cubit.registerExit();
    if (context.mounted) context.pop();
  }

  Future<void> _showExitLimitNotice(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayMedium,
      builder: (ctx) => ExamDialogShell(
        icon: Icons.gavel_rounded,
        accent: AppColors.error,
        title: 'Exam submitted',
        message:
            'You left this exam ${ExamCubit.maxExits} times, which is the '
            'limit. Your answers have been submitted for grading.',
        actions: [
          ExamDialogAction(
            label: 'View result',
            color: AppColors.error,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLeave(BuildContext context, {required int remaining}) {
    final last = remaining == 1;
    final allowance = last
        ? 'This is your final exit. Leaving again after this will submit '
              'your exam automatically.'
        : 'You can leave $remaining more times — after that your exam is '
              'submitted automatically.';
    return showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayMedium,
      builder: (ctx) => ExamDialogShell(
        icon: Icons.logout_rounded,
        accent: AppColors.error,
        title: last ? 'Last time you can leave' : 'Leave exam?',
        message:
            'Your answers are saved automatically, but the timer keeps '
            'running. You can resume from where you left off.\n\n'
            '$allowance',
        actions: [
          ExamDialogAction(
            label: 'Leave exam',
            color: AppColors.error,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          ExamDialogGhostAction(
            label: 'Stay',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  final String? label;
  const _Busy({this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: AppSizes.paddingM),
            Text(
              label!,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.mutedTextPrimary),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              title,
              style: AppTypography.h3SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              message,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.paddingL),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.alwaysWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingXL,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
