import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/exam/presentation/bloc/exam_cubit.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_calculator.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_competitive_view.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_countdown.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_history_sheet.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_intro_view.dart';
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

  /// Owning course id (kept for parity / future use).
  final int courseId;

  /// When non-zero, the node is marked complete on open (purchased flow).
  final int coursePurchasedId;

  const ExamPage({
    super.key,
    required this.examId,
    required this.nodeId,
    required this.courseId,
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
        return sl<ExamCubit>()..open(examId);
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
            taking: (_, __, ___, ____) => true,
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
          taking: (_, __, ___, ____) => true,
          competitiveQuestion: (_, __, ___, ____) => true,
          sectionTransition: (_, __, ___, ____) => true,
          orElse: () => false,
        );

        // Read from the response being rendered rather than a cached copy
        // — an admin can flip the setting mid-attempt, and competitive
        // mode re-fetches it with every question. Assigned during build
        // (no setState) because it is consumed by this same build.
        state.maybeWhen(
          taking: (paper, _, __, ___) {
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
            final leave = await _confirmLeave(context);
            if (leave == true && context.mounted) context.pop();
          },
          child: Scaffold(
            backgroundColor: AppColors.scaffoldLight,
            appBar: CustomAppBar(
              title: state.maybeWhen(
                gate: (g) => g.examTitle,
                taking: (paper, _, __, ___) => paper.examTitle,
                competitiveQuestion: (data, _, __, ___) => data.examTitle,
                result: (r) => r.examTitle,
                orElse: () => 'Exam',
              ),
              centerTitle: false,
              backgroundColor: AppColors.white,
              titleColor: AppColors.textPrimary,
              onBackPressed: () async {
                if (isTaking) {
                  final leave = await _confirmLeave(context);
                  if (leave == true && context.mounted) context.pop();
                } else {
                  context.pop();
                }
              },
              actions: [
                () {
                  final deadline = state.maybeWhen(
                    taking: (_, __, d, ___) => d,
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
      taking: (paper, answers, deadline, stopped) => ExamPaperView(
        paper: paper,
        answers: answers,
        autosaveStopped: stopped,
        onUpdateAnswer: cubit.updateAnswer,
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

  Future<bool?> _confirmLeave(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        title: Text(
          'Leave exam?',
          style: AppTypography.bodyTextXtraLargeSemiBold,
        ),
        content: Text(
          'Your answers are saved automatically, but the timer keeps running. '
          'You can resume from where you left off.',
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.alwaysWhite,
            ),
            child: const Text('Leave'),
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
