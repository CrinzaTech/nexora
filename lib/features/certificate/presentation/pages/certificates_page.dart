import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/presentation/bloc/certificate_cubit.dart';
import 'package:nexora/features/certificate/presentation/widgets/certificate_course_tile.dart';

/// Course Certificates — every course the learner has finished, with a
/// download action on the ones the educator issues a certificate for.
///
/// Courses without a certificate are still listed (with a quiet label
/// instead of a button): the completion is real and worth showing, and
/// hiding those rows would make a full list look mysteriously short.
class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<CertificateCubit>()..load(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: const CustomAppBar(title: 'Course Certificates'),
        body: SafeArea(
          child: BlocBuilder<CertificateCubit, CertificateState>(
            builder: (context, state) {
              return state.maybeWhen(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (message) => _Refreshable(
                  child: _Message(
                    icon: Icons.error_outline,
                    iconColor: AppColors.error,
                    title: 'Something went wrong',
                    body: message,
                  ),
                ),
                loaded: (courses) => _CertificateList(courses: courses),
                orElse: () => const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CertificateList extends StatelessWidget {
  final List<CompletedCourse> courses;

  const _CertificateList({required this.courses});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _Refreshable(
        child: _Message(
          icon: Icons.emoji_events_outlined,
          title: 'No completed courses yet',
          body: 'Finish a course and its certificate will show up here.',
        ),
      );
    }

    // `hasCertificate` is off by default on every course, so a list where
    // none of them issue one is common — say so at the top rather than
    // leaving a page of rows that all read "no certificate" and look broken.
    final noneIssueCertificates = courses.every((c) => !c.hasCertificate);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<CertificateCubit>().silentRefresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 20, vertical: 16),
        itemCount: courses.length + (noneIssueCertificates ? 1 : 0),
        separatorBuilder: (_, __) =>
            SizedBox(height: Screen.getVerticalSize(14)),
        itemBuilder: (_, i) {
          if (noneIssueCertificates && i == 0) return const _NoticeBanner();
          final course = courses[noneIssueCertificates ? i - 1 : i];
          return CertificateCourseTile(
            // A learner can hold two enrolments in one course, so the
            // enrolment row — not the course — is the stable key.
            key: ValueKey(course.purchasedId),
            course: course,
          );
        },
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(all: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: Screen.getSize(18),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: Text(
              'None of your courses issue certificates yet. Your educator '
              'turns these on per course.',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(12),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a non-list state so pull-to-refresh still works — a plain
/// [Center] isn't scrollable, so [RefreshIndicator] has nothing to catch.
class _Refreshable extends StatelessWidget {
  final Widget child;

  const _Refreshable({required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<CertificateCubit>().load(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: constraints.maxHeight, child: child)],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String body;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor ?? AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(16),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
