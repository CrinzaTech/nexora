import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/star_rating.dart';
import 'package:nexora/features/courses/presentation/bloc/course_reviews_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dialog for submitting a review on a course.
///
/// Use [show] to display it. The caller must already have a
/// [CourseReviewsCubit] in scope — typically the Reviews tab — because the
/// dialog adopts that cubit via [BlocProvider.value] and calls
/// [CourseReviewsCubit.submit] when the user taps Save.
class WriteReviewDialog extends StatefulWidget {
  final int courseId;

  const WriteReviewDialog({super.key, required this.courseId});

  /// Opens the dialog. Returns when it is closed (either by Save or X).
  static Future<void> show(BuildContext context, int courseId) {
    final cubit = context.read<CourseReviewsCubit>();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => BlocProvider<CourseReviewsCubit>.value(
        value: cubit,
        child: WriteReviewDialog(courseId: courseId),
      ),
      transitionBuilder: (_, animation, __, child) {
        final scaleCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final fadeCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: fadeCurve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleCurve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<WriteReviewDialog> {
  final TextEditingController _messageController = TextEditingController();

  /// Stored as a double so users can pick half-star ratings (0.5, 1.0, 1.5...).
  double _rating = 0;

  /// Holds the current validation or API error message to display inline.
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Minimum review length the backend / product wants to accept. Used
  /// for both the Save-button enable check and the submit-time guard.
  static const int _minMessageLength = 5;

  bool get _isValid =>
      _rating > 0 && _messageController.text.trim().length >= _minMessageLength;

  void _onSubmit() {
    final trimmed = _messageController.text.trim();

    if (_rating <= 0) {
      Utils.debugLog(
        'WriteReviewDialog: submit blocked — rating missing '
        '(messageLen=${trimmed.length})',
      );
      setState(() {
        _errorMessage =
            'Rating required. Please tap the stars to rate this course.';
      });
      return;
    }

    if (trimmed.isEmpty) {
      Utils.debugLog('WriteReviewDialog: submit blocked — message empty');
      setState(() {
        _errorMessage =
            'Review required. Please write a short review before saving.';
      });
      return;
    }

    if (trimmed.length < _minMessageLength) {
      Utils.debugLog(
        'WriteReviewDialog: submit blocked — message too short '
        '(len=${trimmed.length}, min=$_minMessageLength)',
      );
      setState(() {
        _errorMessage =
            'Review too short. Please write at least $_minMessageLength characters.';
      });
      return;
    }

    // Clear previous errors
    setState(() {
      _errorMessage = null;
    });

    Utils.debugLog(
      'WriteReviewDialog: submitting review '
      '(courseId=${widget.courseId}, '
      'rating=${_rating.toStringAsFixed(1)}, '
      'messageLen=${_messageController.text.trim().length})',
    );
    context.read<CourseReviewsCubit>().submit(
      courseId: widget.courseId,
      rating: _rating,
      reviewMessage: _messageController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CourseReviewsCubit, CourseReviewsState>(
      listenWhen: (previous, current) => current.maybeWhen(
        submitted: () => true,
        error: (_) => true,
        orElse: () => false,
      ),
      listener: (context, state) {
        state.maybeWhen(
          submitted: () {
            // Dialog pops FIRST, then the success snackbar shows safely underneath
            Navigator.of(context).pop();
            CustomSnackbar.success(
              context,
              title: 'Thanks!',
              message: 'Your review was submitted.',
            );
          },
          error: (message) {
            // Display API errors inline as well, since the dialog is still open
            setState(() {
              _errorMessage = message;
            });
          },
          orElse: () {},
        );
      },
      child: Dialog(
        backgroundColor: AppColors.white,
        insetPadding: Screen.getPadding(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: Screen.getPadding(all: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Write a Review',
                        style: AppTypography.h5SemiBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: AppColors.mutedTextPrimary,
                        size: Screen.getSize(22),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: Screen.getVerticalSize(16)),

                // Star row
                InteractiveStarRating(
                  rating: _rating,
                  onChanged: (value) {
                    Utils.debugLog(
                      'WriteReviewDialog: rating changed '
                      '${_rating.toStringAsFixed(1)} -> '
                      '${value.toStringAsFixed(1)} '
                      '(courseId=${widget.courseId})',
                    );
                    setState(() {
                      _rating = value;
                      _errorMessage = null; // Clear error on interaction
                    });
                  },
                ),

                SizedBox(height: Screen.getVerticalSize(16)),

                // Review text field
                TextField(
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 500,
                  onChanged: (_) {
                    setState(() {
                      _errorMessage = null; // Clear error on typing
                    });
                  },
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    fillColor: AppColors.white,
                    hintText: 'Write more about your experience here.',
                    hintStyle: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.mutedTextPrimary.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    contentPadding: Screen.getPadding(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      borderSide: BorderSide(
                        color: AppColors.mutedTextPrimary.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: Screen.getVerticalSize(6)),

                // Live counter
                Builder(
                  builder: (context) {
                    final length = _messageController.text.trim().length;
                    final met = length >= _minMessageLength;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        met
                            ? '$length characters'
                            : '$length / $_minMessageLength min',
                        style: AppTypography.bodyTextMedium.copyWith(
                          fontSize: Screen.getFontSize(12),
                          color: met
                              ? AppColors.primary
                              : AppColors.mutedTextPrimary,
                        ),
                      ),
                    );
                  },
                ),

                // Inline Error Message Display
                if (_errorMessage != null) ...[
                  SizedBox(height: Screen.getVerticalSize(8)),
                  Container(
                    width: double.infinity,
                    padding: Screen.getPadding(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: Screen.getSize(16),
                        ),
                        SizedBox(width: Screen.getSize(8)),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: Screen.getVerticalSize(14)),

                // Save button
                Center(
                  child: BlocBuilder<CourseReviewsCubit, CourseReviewsState>(
                    builder: (context, state) {
                      final isSubmitting = state.maybeWhen(
                        submitting: () => true,
                        orElse: () => false,
                      );
                      return SizedBox(
                        width: Screen.width * 0.45,
                        child: CustomActionButton(
                          name: 'Save',
                          // Optional: if you want the button entirely disabled until valid, keep this.
                          // If you want users to be able to tap it to see the error, change this to: `isFormFilled: !isSubmitting,`
                          isFormFilled: _isValid && !isSubmitting,
                          buttonHeight: 48,
                          onTap: (startLoading, stopLoading, _) {
                            if (isSubmitting) return;
                            _onSubmit();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// import 'package:nexora/core/theme/app_colors.dart';
// import 'package:nexora/core/theme/app_sizes.dart';
// import 'package:nexora/core/theme/app_typography.dart';
// import 'package:nexora/core/theme/screen.dart';
// import 'package:nexora/core/utils/utils.dart';
// import 'package:nexora/core/widgets/custom_action_button.dart';
// import 'package:nexora/core/widgets/custom_snackbar.dart';
// import 'package:nexora/core/widgets/star_rating.dart';
// import 'package:nexora/features/courses/presentation/bloc/course_reviews_cubit.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// /// Dialog for submitting a review on a course.
// ///
// /// Use [show] to display it. The caller must already have a
// /// [CourseReviewsCubit] in scope — typically the Reviews tab — because the
// /// dialog adopts that cubit via [BlocProvider.value] and calls
// /// [CourseReviewsCubit.submit] when the user taps Save.
// class WriteReviewDialog extends StatefulWidget {
//   final int courseId;

//   const WriteReviewDialog({super.key, required this.courseId});

//   /// Opens the dialog. Returns when it is closed (either by Save or X).
//   ///
//   /// Uses [showGeneralDialog] so we can ship a fade + slight pop-scale
//   /// transition instead of `showDialog`'s abrupt fade. Open uses
//   /// [Curves.easeOutBack] for a small overshoot; close uses
//   /// [Curves.easeInCubic] for a quick fade-out.
//   static Future<void> show(BuildContext context, int courseId) {
//     final cubit = context.read<CourseReviewsCubit>();
//     return showGeneralDialog<void>(
//       context: context,
//       // The user has to use the close button or Save — tapping the dim
//       // outside the card no longer dismisses the dialog (would lose any
//       // typed text without warning).
//       barrierDismissible: false,
//       useRootNavigator: true,
//       barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
//       barrierColor: Colors.black.withValues(alpha: 0.45),
//       transitionDuration: const Duration(milliseconds: 320),
//       pageBuilder: (_, __, ___) => BlocProvider<CourseReviewsCubit>.value(
//         value: cubit,
//         child: WriteReviewDialog(courseId: courseId),
//       ),
//       transitionBuilder: (_, animation, __, child) {
//         final scaleCurve = CurvedAnimation(
//           parent: animation,
//           curve: Curves.easeOutBack,
//           reverseCurve: Curves.easeInCubic,
//         );
//         final fadeCurve = CurvedAnimation(
//           parent: animation,
//           curve: Curves.easeOut,
//           reverseCurve: Curves.easeIn,
//         );
//         return FadeTransition(
//           opacity: fadeCurve,
//           child: ScaleTransition(
//             scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleCurve),
//             child: child,
//           ),
//         );
//       },
//     );
//   }

//   @override
//   State<WriteReviewDialog> createState() => _WriteReviewDialogState();
// }

// class _WriteReviewDialogState extends State<WriteReviewDialog> {
//   final TextEditingController _messageController = TextEditingController();

//   /// Stored as a double so users can pick half-star ratings (0.5, 1.0, 1.5...).
//   double _rating = 0;

//   @override
//   void dispose() {
//     _messageController.dispose();
//     super.dispose();
//   }

//   /// Minimum review length the backend / product wants to accept. Used
//   /// for both the Save-button enable check and the submit-time guard.
//   static const int _minMessageLength = 25;

//   bool get _isValid =>
//       _rating > 0 && _messageController.text.trim().length >= _minMessageLength;

//   void _onSubmit() {
//     final trimmed = _messageController.text.trim();

//     if (_rating <= 0) {
//       Utils.debugLog(
//         'WriteReviewDialog: submit blocked — rating missing '
//         '(messageLen=${trimmed.length})',
//       );
//       CustomSnackbar.error(
//         context,
//         title: 'Rating required',
//         message: 'Please tap the stars to rate this course.',
//       );
//       return;
//     }

//     if (trimmed.isEmpty) {
//       Utils.debugLog('WriteReviewDialog: submit blocked — message empty');
//       CustomSnackbar.error(
//         context,
//         title: 'Review required',
//         message: 'Please write a short review before saving.',
//       );
//       return;
//     }

//     if (trimmed.length < _minMessageLength) {
//       Utils.debugLog(
//         'WriteReviewDialog: submit blocked — message too short '
//         '(len=${trimmed.length}, min=$_minMessageLength)',
//       );
//       CustomSnackbar.error(
//         context,
//         title: 'Review too short',
//         message:
//             'Please write at least $_minMessageLength characters '
//             '(${trimmed.length}/$_minMessageLength).',
//       );
//       return;
//     }
//     Utils.debugLog(
//       'WriteReviewDialog: submitting review '
//       '(courseId=${widget.courseId}, '
//       'rating=${_rating.toStringAsFixed(1)}, '
//       'messageLen=${_messageController.text.trim().length})',
//     );
//     context.read<CourseReviewsCubit>().submit(
//       courseId: widget.courseId,
//       rating: _rating,
//       reviewMessage: _messageController.text.trim(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<CourseReviewsCubit, CourseReviewsState>(
//       listenWhen: (previous, current) => current.maybeWhen(
//         submitted: () => true,
//         error: (_) => true,
//         orElse: () => false,
//       ),
//       listener: (context, state) {
//         state.maybeWhen(
//           submitted: () {
//             Navigator.of(context).pop();
//             CustomSnackbar.success(
//               context,
//               title: 'Thanks!',
//               message: 'Your review was submitted.',
//             );
//           },
//           error: (message) {
//             CustomSnackbar.error(
//               context,
//               title: 'Could not submit',
//               message: message,
//             );
//           },
//           orElse: () {},
//         );
//       },
//       child: Dialog(
//         backgroundColor: AppColors.white,
//         insetPadding: Screen.getPadding(horizontal: 24),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(AppSizes.radiusXL),
//         ),
//         child: Padding(
//           padding: Screen.getPadding(all: 20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Write a Review',
//                       style: AppTypography.h5SemiBold.copyWith(
//                         color: AppColors.textPrimary,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     visualDensity: VisualDensity.compact,
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                     onPressed: () => Navigator.of(context).pop(),
//                     icon: Icon(
//                       Icons.close,
//                       color: AppColors.mutedTextPrimary,
//                       size: Screen.getSize(22),
//                     ),
//                   ),
//                 ],
//               ),

//               SizedBox(height: Screen.getVerticalSize(16)),

//               // Star row — supports half-star selection (tap left half = .5,
//               // right half = 1.0).
//               InteractiveStarRating(
//                 rating: _rating,
//                 onChanged: (value) {
//                   Utils.debugLog(
//                     'WriteReviewDialog: rating changed '
//                     '${_rating.toStringAsFixed(1)} -> '
//                     '${value.toStringAsFixed(1)} '
//                     '(courseId=${widget.courseId})',
//                   );
//                   setState(() => _rating = value);
//                 },
//               ),

//               SizedBox(height: Screen.getVerticalSize(16)),

//               // Review text field
//               TextField(
//                 controller: _messageController,
//                 minLines: 5,
//                 maxLines: 8,
//                 maxLength: 500,
//                 onChanged: (_) => setState(() {}),
//                 style: AppTypography.bodyTextMedium.copyWith(
//                   color: AppColors.textPrimary,
//                 ),

//                 decoration: InputDecoration(
//                   fillColor: AppColors.white,
//                   hintText: 'Write more about your experience here.',
//                   hintStyle: AppTypography.bodyTextMedium.copyWith(
//                     color: AppColors.mutedTextPrimary.withValues(alpha: 0.6),
//                   ),
//                   counterText: '',
//                   contentPadding: Screen.getPadding(
//                     horizontal: 14,
//                     vertical: 14,
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(AppSizes.radiusM),
//                     borderSide: BorderSide(
//                       color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
//                     ),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(AppSizes.radiusM),
//                     borderSide: BorderSide(
//                       color: AppColors.primary,
//                       width: 1.5,
//                     ),
//                   ),
//                 ),
//               ),

//               SizedBox(height: Screen.getVerticalSize(6)),

//               // Live counter — turns primary once the user crosses the
//               // minimum length so they know the Save button is unlocked.
//               Builder(
//                 builder: (context) {
//                   final length = _messageController.text.trim().length;
//                   final met = length >= _minMessageLength;
//                   return Align(
//                     alignment: Alignment.centerRight,
//                     child: Text(
//                       met
//                           ? '$length characters'
//                           : '$length / $_minMessageLength min',
//                       style: AppTypography.bodyTextMedium.copyWith(
//                         fontSize: Screen.getFontSize(12),
//                         color: met
//                             ? AppColors.primary
//                             : AppColors.mutedTextPrimary,
//                       ),
//                     ),
//                   );
//                 },
//               ),

//               SizedBox(height: Screen.getVerticalSize(14)),

//               // Save button
//               Center(
//                 child: BlocBuilder<CourseReviewsCubit, CourseReviewsState>(
//                   builder: (context, state) {
//                     final isSubmitting = state.maybeWhen(
//                       submitting: () => true,
//                       orElse: () => false,
//                     );
//                     return SizedBox(
//                       width: Screen.width * 0.45,
//                       child: CustomActionButton(
//                         name: 'Save',
//                         isFormFilled: _isValid && !isSubmitting,
//                         buttonHeight: 48,
//                         onTap: (startLoading, stopLoading, _) {
//                           if (isSubmitting) return;
//                           _onSubmit();
//                         },
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
