import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Reusable snackbar utility using `awesome_snackbar_content`.
///
/// Uses [AppColors] for consistent theming across the app.
///
/// Usage:
/// ```dart
/// CustomSnackbar.success(context, title: 'Done', message: 'Profile updated');
/// CustomSnackbar.error(context, title: 'Oops', message: 'Something went wrong');
/// CustomSnackbar.warning(context, title: 'Warning', message: 'Low storage');
/// CustomSnackbar.info(context, title: 'Info', message: 'New update available');
/// ```
class CustomSnackbar {
  CustomSnackbar._();

  static void success(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: ContentType.success,
      color: AppColors.success,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: ContentType.failure,
      color: AppColors.error,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: ContentType.warning,
      color: AppColors.warning,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: ContentType.help,
      color: AppColors.primary,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType type,
    required Color color,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          duration: duration,
          content: AwesomeSnackbarContent(
            title: title,
            message: message,
            contentType: type,
            color: color,
            // false → the close (X) tap dispatches hideCurrentSnackBar
            // on ScaffoldMessenger. With `true` the package hides a
            // MaterialBanner instead, which we don't use here, so the
            // tap was a no-op.
            inMaterialBanner: false,
          ),
        ),
      );
  }
}
