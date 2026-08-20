import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/presentation/bloc/certificate_cubit.dart';
import 'package:nexora/features/certificate/presentation/certificate_download_action.dart';

/// One completed course on the Certificates screen.
///
/// Three trailing states, and they are genuinely different to a learner:
///   * no certificate  → say so quietly, offer nothing
///   * issued before   → "Download again", with the number on the card
///   * never issued    → a plain "Get certificate" action
///
/// Owns its own `busy` flag rather than reading one off the cubit, so a
/// slow download spins on this row alone and leaves the rest of the list
/// tappable.
class CertificateCourseTile extends StatefulWidget {
  final CompletedCourse course;

  const CertificateCourseTile({super.key, required this.course});

  @override
  State<CertificateCourseTile> createState() => _CertificateCourseTileState();
}

class _CertificateCourseTileState extends State<CertificateCourseTile> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);

    final downloaded = await openCertificate(
      context,
      courseId: widget.course.courseId,
      courseName: widget.course.courseName,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    // The first download assigns the certificate number and flips
    // `isIssued`; refresh so the row shows both when the learner comes
    // back from the viewer.
    if (downloaded) context.read<CertificateCubit>().silentRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final df = DateFormat('d MMM yyyy');

    return Container(
      padding: Screen.getPadding(all: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: AppDecorations.cardBorder(
          lightColor: AppColors.mutedTextPrimary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(course: course),
          SizedBox(width: Screen.getHorizontalSize(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSize(14),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(4)),
                Text(
                  course.completedAt == null
                      ? 'Completed'
                      : 'Completed ${df.format(course.completedAt!)}',
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontSize: Screen.getFontSize(12),
                  ),
                ),
                // The number is what a learner quotes to an employer —
                // surface it instead of hiding it inside the PDF.
                if (course.certificateNo != null &&
                    course.certificateNo!.isNotEmpty) ...[
                  SizedBox(height: Screen.getVerticalSize(4)),
                  Text(
                    'No. ${course.certificateNo}',
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.success,
                      fontSize: Screen.getFontSize(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: Screen.getVerticalSize(10)),
                _action(course),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(CompletedCourse course) {
    if (!course.hasCertificate) {
      // Certificates are off by default on every course, so this is the
      // common case — state it plainly and offer nothing to tap.
      return Text(
        'No certificate for this course',
        style: AppTypography.bodyTextMedium.copyWith(
          color: AppColors.grey400,
          fontSize: Screen.getFontSize(12),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (_busy) {
      return Row(
        children: [
          SizedBox(
            width: Screen.getSize(16),
            height: Screen.getSize(16),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Text(
            'Preparing…',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontSize: Screen.getFontSize(12),
            ),
          ),
        ],
      );
    }

    return FilledButton.tonalIcon(
      onPressed: _download,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        foregroundColor: AppColors.primary,
        padding: Screen.getPadding(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      icon: Icon(Icons.download_rounded, size: Screen.getSize(16)),
      label: Text(
        course.isIssued ? 'Download again' : 'Get certificate',
        style: AppTypography.bodyTextMedium.copyWith(
          color: AppColors.primary,
          fontSize: Screen.getFontSize(13),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Course image when the API ships a resolvable URL, otherwise a medal.
///
/// `thumbnail` is an S3 object key on this endpoint and the app has no
/// key→URL resolver, so most rows land on the icon — see
/// [CompletedCourse.thumbnailUrl].
class _Thumbnail extends StatelessWidget {
  final CompletedCourse course;

  const _Thumbnail({required this.course});

  @override
  Widget build(BuildContext context) {
    final side = Screen.getSize(56);
    final fallback = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: course.hasCertificate
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      alignment: Alignment.center,
      child: Icon(
        course.hasCertificate
            ? Icons.workspace_premium
            : Icons.workspace_premium_outlined,
        color: course.hasCertificate ? AppColors.primary : AppColors.grey300,
        size: Screen.getSize(26),
      ),
    );

    final url = course.thumbnailUrl;
    if (url == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: CustomNetworkImage(
        url: url,
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorWidget: fallback,
      ),
    );
  }
}
