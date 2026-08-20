import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/auth/presentation/bloc/org_code_cubit.dart';

/// Organisation code entry page.
///
/// Shown before the Login page only when `ORG_ID=CRINZA` in `.env`.
/// Mirrors the OTP page visual design (background image + glass card +
/// 6-cell Pinput) but accepts any alphanumeric character, not just digits.
///
/// **Skip** → navigates to Login without setting an org code (the OTP
///   use cases will fall back to the `.env ORG_ID` value).
/// **Continue** → calls `/api/v1/validate-org-code`; on success stores
///   the code in `OrgCodeService` and navigates to Login.
class OrgCodePage extends StatefulWidget {
  const OrgCodePage({super.key});

  @override
  State<OrgCodePage> createState() => _OrgCodePageState();
}

class _OrgCodePageState extends State<OrgCodePage> {
  final TextEditingController _codeController = TextEditingController();
  DateTime? _lastBackPressTime;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_codeController.text.trim().length == 6) {
      context.read<OrgCodeCubit>().validate(_codeController.text);
    }
  }

  void _handleSkip() {
    context.go(AppRoutes.login);
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
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: BlocConsumer<OrgCodeCubit, OrgCodeState>(
          listener: (context, state) {
            if (state is OrgCodeValid) {
              // Code validated — proceed to login.
              context.go(AppRoutes.login);
            } else if (state is OrgCodeError) {
              CustomSnackbar.error(
                context,
                title: 'Invalid Code',
                message: 'Please enter the correct org code',
              );
              // Reset so the user can retry immediately.
              context.read<OrgCodeCubit>().reset();
            }
          },
          builder: (context, state) {
            final isLoading = state is OrgCodeLoading;
            return Stack(
              children: [
                // ── Background ──────────────────────────────────────────
                Positioned.fill(
                  child: Image.asset(
                    AppImages.loginBackground,
                    fit: BoxFit.cover,
                  ),
                ),
                // ── Form content ────────────────────────────────────────
                Positioned.fill(
                  child: _OrgCodeFormContent(
                    codeController: _codeController,
                    onCodeChanged: (_) => setState(() {}),
                    onContinuePressed: _handleContinue,
                    onSkipPressed: _handleSkip,
                  ),
                ),
                // ── Loading overlay ─────────────────────────────────────
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
    ));
  }
}

// ─── Form content ─────────────────────────────────────────────────────────

class _OrgCodeFormContent extends StatelessWidget {
  final TextEditingController codeController;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onContinuePressed;
  final VoidCallback onSkipPressed;

  const _OrgCodeFormContent({
    required this.codeController,
    required this.onCodeChanged,
    required this.onContinuePressed,
    required this.onSkipPressed,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    final isFilled = codeController.text.trim().length == 6;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final cardHeight = Screen.getSafeHeight(context) * 0.62 + bottomInset;

    // Using a plain Column (not ScrollView) so:
    //  • Expanded logo section takes all space above the card.
    //  • Fixed-height card always sits flush at the bottom.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo — floats in whatever space is above the card ────────
          Expanded(
            child: Center(
              child: Image.asset(
                AppImages.logoWithText,
                scale: 2,
                height: 150,
              ),
            ),
          ),

          // ── Glass card — fixed height, pinned at bottom ──────────────
          SizedBox(
            height: cardHeight,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                Screen.getHorizontalSize(AppSizes.paddingL),
                Screen.getVerticalSize(AppSizes.paddingL),
                Screen.getHorizontalSize(AppSizes.paddingL),
                Screen.getVerticalSize(AppSizes.paddingL) + bottomInset,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
                border: Border(
                  top: BorderSide(
                    width: 1.5,
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                  left: BorderSide(
                    width: 1.5,
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                  right: BorderSide(
                    width: 1.5,
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title ───────────────────────────────────────────
                  Text(
                    'Enter Entity Code',
                    textAlign: TextAlign.center,
                    style: AppTypography.h4SemiBold.copyWith(
                      fontSize: Screen.getFontSize(27),
                      letterSpacing: -0.01,
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(6)),
                  Text(
                    '6-character code',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyTextMedium.copyWith(
                      fontSize: Screen.getFontSize(14),
                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                      letterSpacing: -0.01,
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(55)),
                  // ── Pinput ──────────────────────────────────────────
                  _OrgCodeInputField(
                    controller: codeController,
                    onChanged: onCodeChanged,
                  ),
                  // ── Spacer pushes buttons to card bottom ────────────
                  const Spacer(),
                  // ── Action row: Skip left | Continue right ──────────
                  Row(
                    children: [
                      // Skip — outlined pill
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: Screen.getHorizontalSize(8),
                          ),
                          child: GestureDetector(
                            onTap: onSkipPressed,
                            child: Container(
                              height: Screen.getVerticalSize(48),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Skip',
                                style: AppTypography.bodyTextSemiBold.copyWith(
                                  fontSize: Screen.getFontSizeCapped(16),
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Continue — filled primary pill
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: Screen.getHorizontalSize(8),
                          ),
                          child: CustomActionButton(
                            onTap: (startLoading, stopLoading, btnState) {
                              if (isFilled) onContinuePressed();
                            },
                            name: 'Continue',
                            isFormFilled: isFilled,
                            buttonHeight: Screen.getVerticalSize(48),
                          ),
                        ),
                      ),
                    ],
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


// ─── 6-cell alphanumeric input ─────────────────────────────────────────────

class _OrgCodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _OrgCodeInputField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: Screen.getHorizontalSize(60),
      height: Screen.getVerticalSize(65),
      textStyle: AppTypography.h4SemiBold.copyWith(
        color: AppColors.textPrimary,
        fontSize: Screen.getFontSize(22),
      ),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.alwaysWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
    );

    return Pinput(
      length: 6,
      controller: controller,
      onChanged: onChanged,
      // Accept any character — letters and digits both allowed.
      keyboardType: TextInputType.text,
      // No autofill — this is a custom org code, not an OTP.
      autofillHints: const [],
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: defaultPinTheme,
      followingPinTheme: defaultPinTheme,
    );
  }
}
