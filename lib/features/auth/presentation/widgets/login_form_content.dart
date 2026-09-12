import 'package:nexora/core/config/auth_policy.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/features/auth/presentation/pages/login_page.dart'
    show LoginMode;
import 'package:nexora/features/auth/presentation/widgets/email_input_field.dart';
import 'package:nexora/features/auth/presentation/widgets/google_email_picker_field.dart';
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
    required this.onSendOTPPressed,
    required this.onGooglePickEmailPressed,
    required this.onNextPressed,
    required this.onEditPhonePressed,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final Country selectedCountry;
  final LoginMode mode;
  final bool isLoading;
  final ValueChanged<Country> onCountrySelected;

  /// Async — called when the user taps "Send OTP". The page awaits
  /// this and clears [isLoading] in its `finally` block.
  final Future<void> Function() onSendOTPPressed;

  /// Async — called when the user taps "Continue with Google" (or
  /// "Change" on an already-picked email). The page opens the native
  /// account picker and fills [emailController] with the result;
  /// sending the OTP is a separate "Send OTP" tap.
  final Future<void> Function() onGooglePickEmailPressed;

  /// Called instead of [onSendOTPPressed] on the non-India phone screen,
  /// where the button reads "Next" — it validates the number and moves
  /// the user to the email step rather than dispatching an SMS.
  final VoidCallback onNextPressed;

  /// Pencil beside the carried number on the email step — returns to the
  /// phone screen with what was typed still intact.
  final VoidCallback onEditPhonePressed;

  bool get _isPhone => mode == LoginMode.phone;

  /// Indian numbers always reach the SMS gateway, so phone OTP is the
  /// whole story there and the email alternative only adds a way to
  /// get it wrong. Everywhere else email is the reachable channel.
  bool get _isIndia => selectedCountry.dialCode == '+91';

  /// Outside India the phone screen doesn't send anything — SMS won't
  /// reach these learners, so the number is collected and the flow hands
  /// off to email for the actual verification. The button says "Next"
  /// rather than "Send OTP" so it doesn't promise a message that never
  /// arrives.
  bool get _isPhoneHandoff => _isPhone && !_isIndia;

  /// Shows the already-collected number above the email step so it can
  /// still be corrected. Guarded on country as well as on there being a
  /// number, since India never carries one into email mode.
  bool get _showCarriedPhoneField =>
      !_isPhone && !_isIndia && phoneController.text.trim().isNotEmpty;

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
                      // Explicit rhythm rather than spaceEvenly: the
                      // children differ between phone and email mode, so
                      // even distribution spread them into voids and the
                      // gaps jumped between screens. Related things are
                      // now grouped tightly and the legal line is pinned
                      // to the bottom by a single Spacer.
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: Screen.getVerticalSize(28)),
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
                              _isPhoneHandoff
                                  ? "We'll verify you by email in the next step."
                                  : _isPhone
                                  ? "We will send a 6-digit code to your number."
                                  : "Choose the email you'd like to use.",
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
                        SizedBox(height: Screen.getVerticalSize(32)),
                        // Mode-driven input — PhoneInputField for phone;
                        // email prefers the Google account picker, which
                        // kills the typo-in-address failure mode entirely.
                        // Where that picker isn't allowed (iOS, guideline
                        // 4.8 — see [AuthPolicy]) the same address is
                        // typed instead. All three share the 52pt pill
                        // geometry so the layout doesn't shift on toggle.
                        if (_isPhone)
                          PhoneInputField(
                            controller: phoneController,
                            initialCountry: selectedCountry,
                            onCountryChanged: onCountrySelected,
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The number collected before the hand-off,
                              // shown read-only so the learner can see
                              // what they're signing up with. The pencil
                              // is the only way back to the phone screen
                              // now that the mode toggle is gone.
                              if (_showCarriedPhoneField) ...[
                                _CarriedPhonePreview(
                                  country: selectedCountry,
                                  phone: phoneController.text.trim(),
                                  onEdit: onEditPhonePressed,
                                ),
                                SizedBox(height: Screen.getVerticalSize(14)),
                              ],
                              if (AuthPolicy.allowsGoogleEmailPicker)
                                GoogleEmailPickerField(
                                  email: emailController.text,
                                  isLoading: isLoading,
                                  onPick: onGooglePickEmailPressed,
                                )
                              else
                                EmailInputField(
                                  controller: emailController,
                                  enabled: !isLoading,
                                  onSubmitted: onSendOTPPressed,
                                ),
                            ],
                          ),
                        SizedBox(height: Screen.getVerticalSize(32)),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: Screen.getHorizontalSizeCapped(162),
                            // Rebuilds on every keystroke of a typed email so
                            // the button enables as soon as an address is
                            // there. The picker path pushes its result
                            // through the same controller, so one listener
                            // covers both ways of filling the field.
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: emailController,
                              builder: (context, emailValue, _) {
                                final hasEmail = emailValue.text
                                    .trim()
                                    .isNotEmpty;
                                final ready =
                                    !isLoading && (_isPhone || hasEmail);
                                return CustomActionButton(
                                  // isLoading disables the button while the
                                  // OTP request is in-flight so the user
                                  // can't double-tap and trigger duplicate
                                  // API calls. In email mode the button
                                  // stays disabled until an address is
                                  // present, whether picked or typed.
                                  onTap: ready
                                      ? (startLoading, stopLoading, _) {
                                          if (_isPhoneHandoff) {
                                            onNextPressed();
                                          } else {
                                            onSendOTPPressed();
                                          }
                                        }
                                      : (s, e, _) {}, // no-op
                                  name: _isPhoneHandoff ? "Next" : "Send OTP",
                                  isFormFilled: ready,
                                  buttonHeight: Screen.getVerticalSize(48),
                                );
                              },
                            ),
                          ),
                        ),
                        // Everything above sits as one block; the legal
                        // line drops to the foot of the sheet.
                        const Spacer(),
                        if (!kIsWeb &&
                            Platform.isIOS &&
                            dotenv.env['ORG_ID'] == 'CRINZA') ...[
                          GestureDetector(
                            onTap: () {
                              context.go(AppRoutes.orgCode);
                            },
                            child: Text(
                              "Edit Entity Code",
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyTextSemiBold.copyWith(
                                fontSize: Screen.getFontSizeCapped(14),
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          SizedBox(height: Screen.getVerticalSize(16)),
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

/// The number collected on the phone screen, shown back on the email
/// step as a settled piece of information rather than floating text —
/// a labelled surface with its own edit affordance, so it reads as
/// "here's what we already have" instead of looking like a caption
/// attached to the button below it.
class _CarriedPhonePreview extends StatelessWidget {
  const _CarriedPhonePreview({
    required this.country,
    required this.phone,
    required this.onEdit,
  });

  final Country country;
  final String phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
        child: Container(
          padding: Screen.getPadding(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
            border: Border.all(color: AppColors.grey200, width: 1),
          ),
          child: Row(
            children: [
              Text(
                country.flag,
                style: TextStyle(fontSize: Screen.getFontSizeCapped(18)),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Phone number',
                      style: AppTypography.bodyTextMedium.copyWith(
                        fontSize: Screen.getFontSizeCapped(11),
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        letterSpacing: -0.01,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(2)),
                    Text(
                      '${country.dialCode} $phone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        fontSize: Screen.getFontSizeCapped(15),
                        color: AppColors.textPrimary,
                        letterSpacing: -0.01,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Image.asset(
                AppImages.editIcon,
                fit: BoxFit.contain,
                width: Screen.getSize(18),
                height: Screen.getSize(18),
                color: AppColors.primary,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
