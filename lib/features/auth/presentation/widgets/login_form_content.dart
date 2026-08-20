import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:nexora/features/auth/presentation/pages/login_page.dart'
    show LoginMode;
import 'package:nexora/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:nexora/core/router/app_routes.dart';

import '../../../../core/theme/app_images.dart';

class LoginFormContent extends StatelessWidget {
  const LoginFormContent({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.emailController,
    required this.selectedCountry,
    required this.mode,
    required this.isLoading,
    required this.onCountrySelected,
    required this.onToggleMode,
    required this.onSendOTPPressed,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final Country selectedCountry;
  final LoginMode mode;
  final bool isLoading;
  final ValueChanged<Country> onCountrySelected;
  final VoidCallback onToggleMode;

  /// Async — called when the user taps "Send OTP". The page awaits
  /// this and clears [isLoading] in its `finally` block.
  final Future<void> Function() onSendOTPPressed;

  bool get _isPhone => mode == LoginMode.phone;

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: Screen.getSafeHeight(context)),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                SizedBox.fromSize(
                  size: Size.fromHeight(Screen.getSafeHeight(context) * 0.25),
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
                  size: Size.fromHeight(Screen.getSafeHeight(context) * 0.8),
                  child: GlassSheet(
                    padding: Screen.getPadding(all: AppSizes.paddingL),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isPhone
                                  ? "Enter your Number"
                                  : "Enter your Email",
                              style: AppTypography.h4SemiBold.copyWith(
                                fontSize: Screen.getFontSizeCapped(27),
                                letterSpacing: -0.01,
                              ),
                            ),
                            Text(
                              _isPhone
                                  ? "We will send a 6-digit code to your number."
                                  : "We will send a 6-digit code to your email.",
                              style: AppTypography.bodyTextMedium.copyWith(
                                fontSize: Screen.getFontSizeCapped(14),
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.6,
                                ),
                                letterSpacing: -0.01,
                              ),
                            ),
                          ],
                        ),
                        // Mode-driven input — PhoneInputField for phone,
                        // CustomTextFormField (with email validation) for
                        // email. Same outer geometry both sides so the
                        // surrounding form layout doesn't shift on toggle.
                        if (_isPhone)
                          PhoneInputField(controller: phoneController)
                        else
                          Padding(
                            padding: Screen.getPadding(horizontal: 8),
                            child: CustomTextFormField(
                              controller: emailController,

                              hintText: 'Enter your email address',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) {
                                  return 'Please enter your email';
                                }
                                final ok = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(v);
                                if (!ok) return 'Enter a valid email';
                                return null;
                              },
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.grey200,
                                thickness: .75,
                                indent: 30,
                                endIndent: 15,
                              ),
                            ),
                            Text(
                              "OR",
                              style: AppTypography.bodyTextSemiBold.copyWith(
                                fontSize: Screen.getFontSizeCapped(15),
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.28,
                                ),
                                letterSpacing: -0.01,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppColors.grey200,
                                thickness: .75,
                                indent: 15,
                                endIndent: 30,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: Screen.getVerticalSize(52),
                          width: Screen.getHorizontalSizeCapped(
                            320,
                          ), // Increased width
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              // Toggles login mode — the same affordance
                              // flips its label/icon to point at the OTHER
                              // mode so the user always sees the
                              // alternative they can switch to.
                              onTap: onToggleMode,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Screen.getHorizontalSize(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _isPhone
                                              ? "Login using Email Address"
                                              : "Login using Phone Number",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: AppTypography
                                              .bodyTextLargeSemiBold
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontSize:
                                                    Screen.getFontSizeCapped(
                                                      14,
                                                    ),
                                                letterSpacing: -0.01,
                                              ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: Screen.getHorizontalSize(12),
                                      ),
                                      Icon(
                                        _isPhone
                                            ? Icons.mail
                                            : Icons.phone_iphone,
                                        color: AppColors.primary,
                                        size: Screen.getSize(20),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: Screen.getHorizontalSizeCapped(162),
                          child: CustomActionButton(
                            // isLoading disables the button while the
                            // OTP request is in-flight so the user can't
                            // double-tap and trigger duplicate API calls.
                            onTap: isLoading
                                ? (s, e, _) {} // no-op while loading
                                : (startLoading, stopLoading, _) {
                                    onSendOTPPressed();
                                  },
                            name: "Send OTP",
                            isFormFilled: !isLoading,
                            buttonHeight: Screen.getVerticalSize(48),
                          ),
                        ),
                        if (!kIsWeb &&
                            Platform.isIOS &&
                            dotenv.env['ORG_ID'] == 'CRINZA') ...[
                          GestureDetector(
                            onTap: () {
                              context.go(AppRoutes.orgCode);
                            },
                            child: Text(
                              "Edit Entity Code",
                              style: AppTypography.bodyTextSemiBold.copyWith(
                                fontSize: Screen.getFontSizeCapped(14),
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: AppTypography.bodyTextMedium.copyWith(
                              fontSize: Screen.getFontSizeCapped(11),
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.6,
                              ),
                              letterSpacing: -0.01,
                            ),
                            children: [
                              const TextSpan(
                                text: "By continuing you agree to ",
                              ),
                              TextSpan(
                                text: "Terms",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Todo: Navigate to Terms
                                  },
                              ),
                              const TextSpan(text: " & "),
                              TextSpan(
                                text: "Privacy",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Todo: Navigate to Privacy Policy
                                  },
                              ),
                            ],
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
