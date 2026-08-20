import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/certificate/domain/usecases/download_certificate_usecase.dart';

/// Downloads one course's certificate and opens it in the in-app viewer.
///
/// Shared by both entry points — the Certificates screen and the
/// Completed tab of My Courses — so the refusal wording and the
/// success route stay identical wherever the learner taps.
///
/// Callers own the spinner: this returns as soon as the request settles
/// (not when the viewer is closed), so a card can flip its own `busy`
/// flag around the `await` and keep the rest of the list interactive.
///
/// Returns `true` when a certificate was downloaded and the viewer was
/// opened — the first successful download is what flips `isIssued` and
/// assigns a certificate number server-side, so a caller holding a list
/// can use this as its cue to refresh.
Future<bool> openCertificate(
  BuildContext context, {
  required int courseId,
  required String courseName,
}) async {
  final result = await sl<DownloadCertificateUseCase>()(
    courseId: courseId,
    courseName: courseName,
  );

  if (!context.mounted) return false;

  final certificate = result.fold((failure) {
    _showRefusal(context, failure);
    return null;
  }, (certificate) => certificate);

  if (certificate == null) return false;

  context.push(AppRoutes.certificatePreview, extra: certificate);
  return true;
}

/// Surfaces the server's own sentence — the API writes these for
/// learners and they say what to do next, so they're shown verbatim.
///
/// A 409 means the *educator* still has something to pick or unlock; it
/// isn't the learner's mistake, so it reads as information rather than a
/// red failure. 404 (course not completed / certificates switched off)
/// is a warning, and anything else is a genuine error.
void _showRefusal(BuildContext context, Failure failure) {
  final statusCode = failure.maybeWhen(
    server: (_, code) => code,
    orElse: () => null,
  );

  switch (statusCode) {
    case 409:
      CustomSnackbar.info(
        context,
        title: 'Almost there',
        message: failure.message,
        duration: const Duration(seconds: 5),
      );
    case 404:
      CustomSnackbar.warning(
        context,
        title: 'Not available',
        message: failure.message,
        duration: const Duration(seconds: 4),
      );
    default:
      CustomSnackbar.error(
        context,
        title: 'Download failed',
        message: failure.message,
      );
  }
}
