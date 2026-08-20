import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/auth/presentation/bloc/otp_cubit.dart';
import 'package:nexora/features/auth/presentation/widgets/otp_input_field.dart';
import 'package:go_router/go_router.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final String email;

  /// `true` when the OTP was sent to [phoneNumber]; `false` when sent
  /// to [email]. Drives which v2 dispatcher the cubit calls and the
  /// "OTP sent to …" copy underneath the title.
  final bool isPhone;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    this.countryCode = '+91',
    this.email = '',
    this.isPhone = true,
  });

  /// What the v2 endpoints want as their `recipient` query param —
  /// the phone number when [isPhone] is true, the email otherwise.
  String get recipient => isPhone ? phoneNumber : email;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

/// [CodeAutoFill] mixin wires up the Android SMS Retriever API and the
/// iOS OneTimeCode keyboard suggestion automatically. No READ_SMS
/// permission is requested — the system shows its own consent dialog.
class _OtpPageState extends State<OtpPage> with CodeAutoFill {
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _startTimer();
    context.read<OtpCubit>().startTimer();
    // SMS auto-detection is only relevant for phone-based OTP flows.
    // Email OTPs land in the inbox, not via SMS — skip the listener.
    if (widget.isPhone) {
      _startSmsListener();
    }
  }

  /// Activates the Android SMS Retriever / iOS One-Time-Code listener.
  ///
  /// All failure modes (no SIM card, airplane mode, OS version < minimum,
  /// user dismissed the consent dialog, or platform exception) are silently
  /// swallowed so the user still gets the manual-entry fallback.
  Future<void> _startSmsListener() async {
    try {
      final hash = await SmsAutoFill().getAppSignature;
      print('📱 [SMS Autofill] App hash: $hash');
      listenForCode();
    } catch (e) {
      print('[OTP] SMS autofill unavailable: $e');
    }
  }

  /// [CodeAutoFill] calls this once the incoming SMS matches the OTP
  /// pattern. [code] (a `String?` field from the mixin) holds the
  /// extracted digits. Auto-submits when all 6 digits are populated.
  @override
  void codeUpdated() {
    final detected = code;
    if (detected == null || detected.isEmpty || !mounted) return;
    _otpController.text = detected;
    setState(() {}); // Refresh the Verify button enabled state
    if (detected.length == 6) {
      _handleVerify();
    }
  }

  @override
  void dispose() {
    // CodeAutoFill cleanup — unsubscribes from the SMS stream and
    // unregisters the Android broadcast receiver.
    cancel();
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _canResend = false);
    _secondsRemaining = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        context.read<OtpCubit>().updateTimer(_secondsRemaining);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  void _handleVerify() {
    if (_otpController.text.length == 6) {
      context.read<OtpCubit>().verifyOtpV2(
        recipient: widget.recipient,
        otpCode: _otpController.text,
        isPhone: widget.isPhone,
      );
    }
  }

  void _handleResend() {
    if (_canResend) {
      context.read<OtpCubit>().resendOtpV2(
        recipient: widget.recipient,
        isPhone: widget.isPhone,
      );
      _startTimer();
      // Re-arm the SMS listener so the new message is caught after resend.
      if (widget.isPhone) _startSmsListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        // Tap-outside-to-dismiss-keyboard: GestureDetector picks up
        // taps anywhere in the body (opaque so empty space counts) and
        // unfocuses the currently-focused node, which collapses the
        // soft keyboard. The Pinput field's own taps still register
        // because GestureDetector lets descendant gestures win.
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: BlocBuilder<OtpCubit, OtpState>(
            buildWhen: (prev, curr) {
              final prevLoading = prev.maybeWhen(
                loading: () => true,
                orElse: () => false,
              );
              final currLoading = curr.maybeWhen(
                loading: () => true,
                orElse: () => false,
              );
              return prevLoading != currLoading;
            },
            builder: (context, state) {
              final isLoading = state.maybeWhen(
                loading: () => true,
                orElse: () => false,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      AppImages.loginBackground,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: _OtpFormContent(
                      otpController: _otpController,
                      phoneNumber: widget.phoneNumber,
                      countryCode: widget.countryCode,
                      email: widget.email,
                      isPhone: widget.isPhone,
                      secondsRemaining: _secondsRemaining,
                      canResend: _canResend,
                      onOtpChanged: (code) {
                        setState(() {});
                      },
                      onVerifyPressed: _handleVerify,
                      onResendPressed: _handleResend,
                    ),
                  ),
                  // Full-screen loading overlay shown while the cubit is
                  // awaiting the verify / resend API response.
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OtpFormContent extends StatelessWidget {
  final TextEditingController otpController;
  final String phoneNumber;
  final String countryCode;
  final String email;
  final bool isPhone;
  final int secondsRemaining;
  final bool canResend;
  final Function(String) onOtpChanged;
  final VoidCallback onVerifyPressed;
  final VoidCallback onResendPressed;

  const _OtpFormContent({
    required this.otpController,
    required this.phoneNumber,
    required this.countryCode,
    required this.email,
    required this.isPhone,
    required this.secondsRemaining,
    required this.canResend,
    required this.onOtpChanged,
    required this.onVerifyPressed,
    required this.onResendPressed,
  });

  String _formatSeconds(int seconds) {
    return '$seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return SafeArea(
      bottom: false,
      child: BlocListener<OtpCubit, OtpState>(
        listener: (context, state) {
          state.maybeWhen(
            verified: (token, userId, message, isUserAlreadyExist) async {
              if (token != null && token.isNotEmpty) {
                await sl<SessionService>().saveToken(token);
                // Gate the dashboard until setup-profile is actually
                // submitted. Written immediately (before navigation) so
                // the flag survives an app kill/cache-clear that leaves
                // the token in secure storage but the form unfilled.
                await sl<SessionService>().saveProfileComplete(
                  isUserAlreadyExist,
                );
                // A fresh token can unblock content completions that were
                // queued when the previous one expired (they're retried,
                // not dropped, on 401). Drain now rather than making the
                // student wait for the next launch or network flap.
                unawaited(sl<ContentCompletionService>().flushPending());
              }
              if (context.mounted) {
                CustomSnackbar.success(
                  context,
                  title: 'Success',
                  message: message,
                );
                if (isUserAlreadyExist) {
                  context.go(AppRoutes.dashboard);
                } else {
                  // Carry whichever channel the user authenticated on
                  // into setup-profile so the matching field can be
                  // pre-filled (phone → phone field; email → email
                  // field). The page treats empties as "not set yet".
                  final query = isPhone
                      ? 'phone=$phoneNumber&countryCode=$countryCode'
                      : 'email=${Uri.encodeComponent(email)}';
                  context.go('${AppRoutes.setupProfile}?$query');
                }
              }
            },
            resent: (status, message) {
              // status 1 → success (green)
              // status 3 → warning (orange)
              // anything else → error (red)
              if (status == 1) {
                CustomSnackbar.success(
                  context,
                  title: 'OTP Resent',
                  message: message,
                );
              } else if (status == 3) {
                CustomSnackbar.warning(
                  context,
                  title: 'Warning',
                  message: message,
                );
              } else {
                CustomSnackbar.error(context, title: 'Error', message: message);
              }
            },
            error: (message) {
              CustomSnackbar.error(
                context,
                title: 'Verification Failed',
                message: message,
              );
            },
            orElse: () {},
          );
        },
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Screen.getSafeHeight(context),
            ),
            child: Column(
              children: [
                SizedBox.fromSize(
                  size: Size.fromHeight(Screen.getSafeHeight(context) * 0.2),
                  child: Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      AppImages.logoWithText,
                      scale: 2,
                      height: 150,
                    ),
                  ),
                ),
                SizedBox.fromSize(
                  size: Size.fromHeight(
                    Screen.getSafeHeight(context) * 0.8 +
                        MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: GlassSheet(
                    padding: EdgeInsets.fromLTRB(
                      Screen.getHorizontalSize(AppSizes.paddingL),
                      Screen.getVerticalSize(AppSizes.paddingL),
                      Screen.getHorizontalSize(AppSizes.paddingL),
                      Screen.getVerticalSize(AppSizes.paddingL) +
                          MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPhone ? "Verify Phone Number" : "Verify Email",
                              style: AppTypography.h4SemiBold.copyWith(
                                fontSize: Screen.getFontSizeCapped(27),
                                letterSpacing: -0.01,
                              ),
                            ),
                            SizedBox(height: Screen.getVerticalSize(8)),
                            // Wrap (not Row) so a long recipient
                            // — e.g. `mohdsalmanp866@gmail.com` —
                            // drops onto its own line instead of
                            // overflowing the sheet horizontally.
                            // Phone numbers stay inline since they
                            // comfortably fit alongside the prefix.
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "We have sent an OTP to ",
                                  style: AppTypography.bodyTextMedium.copyWith(
                                    fontSize: Screen.getFontSizeCapped(14),
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.6,
                                    ),
                                    letterSpacing: -0.01,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // Pop OTP screen, go back to login to edit number / email
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go(AppRoutes.login);
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: Screen.width * 0.7,
                                        ),
                                        child: Text(
                                          isPhone
                                              ? "+${countryCode.trim()} ${phoneNumber.trim()}"
                                              : email.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyTextSemiBold
                                              .copyWith(
                                                fontSize:
                                                    Screen.getFontSizeCapped(
                                                      14,
                                                    ),
                                                color: AppColors.primary,
                                                letterSpacing: -0.01,
                                              ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: Screen.getHorizontalSize(3),
                                      ),
                                      Image.asset(
                                        AppImages.editIcon,
                                        fit: BoxFit.cover,
                                        width: Screen.getSize(20),
                                        height: Screen.getSize(20),
                                        color: AppColors.primary,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        OtpInputField(
                          controller: otpController,
                          onChanged: onOtpChanged,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            canResend
                                ? GestureDetector(
                                    onTap: onResendPressed,
                                    child: Text(
                                      "Resend Code",
                                      style: AppTypography.bodyTextSemiBold
                                          .copyWith(
                                            fontSize: Screen.getFontSizeCapped(
                                              14,
                                            ),
                                            color: AppColors.primary,
                                          ),
                                    ),
                                  )
                                : RichText(
                                    text: TextSpan(
                                      style: AppTypography.bodyTextMedium
                                          .copyWith(
                                            fontSize: Screen.getFontSizeCapped(
                                              14,
                                            ),
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.6),
                                          ),
                                      children: [
                                        const TextSpan(text: "Resend OTP in "),
                                        TextSpan(
                                          text: _formatSeconds(
                                            secondsRemaining,
                                          ),
                                          style: AppTypography.bodyTextSemiBold
                                              .copyWith(
                                                fontSize:
                                                    Screen.getFontSizeCapped(
                                                      14,
                                                    ),
                                                color: AppColors.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                        SizedBox(
                          width: Screen.getHorizontalSizeCapped(162),
                          child: BlocBuilder<OtpCubit, OtpState>(
                            builder: (context, state) {
                              final isFormFilled =
                                  otpController.text.length == 6;

                              return CustomActionButton(
                                onTap: (startLoading, stopLoading, btnState) {
                                  if (isFormFilled) {
                                    onVerifyPressed();
                                  }
                                },
                                name: "Verify",
                                isFormFilled: isFormFilled,
                                buttonHeight: Screen.getVerticalSize(48),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
