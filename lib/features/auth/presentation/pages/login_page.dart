import 'package:nexora/core/config/auth_policy.dart';
import 'package:nexora/features/auth/presentation/widgets/email_input_field.dart';
import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/auth/data/services/google_account_picker_service.dart';
import 'package:nexora/features/auth/domain/usecases/send_otp_v2_usecase.dart';
import 'package:nexora/features/auth/presentation/widgets/login_form_content.dart';
import 'package:nexora/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Phone vs email login mode toggle owned by [LoginPage].
enum LoginMode { phone, email }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  late Country _selectedCountry;
  LoginMode _mode = LoginMode.phone;
  bool _isLoading = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _defaultCountry;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Country get _defaultCountry =>
      const Country(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳');

  /// Pencil on the email step — back to the number, keeping what was
  /// already typed.
  ///
  /// Deliberately does not reset the form: `FormState.reset()` restores
  /// fields to their initial value, which for the phone field means
  /// empty — it would wipe the very number the learner tapped the pencil
  /// to correct.
  void _handleEditPhone() {
    if (!mounted) return;
    setState(() => _mode = LoginMode.phone);
  }

  Future<void> _handleSendOTP() async {
    if (!mounted) return;

    final isPhone = _mode == LoginMode.phone;
    if (isPhone) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      await _sendOtp(recipient: _phoneController.text.trim(), isPhone: true);
      return;
    }

    // Email mode: the address is either picked from a Google account or
    // typed, depending on platform (see [AuthPolicy]). Both land in the
    // same controller and both reach the backend as a plain string, so
    // there is one send path from here. Only the "it's missing" wording
    // differs, because "pick one" and "type one" are different fixes.
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomSnackbar.error(
        context,
        title: 'Error',
        message: AuthPolicy.allowsGoogleEmailPicker
            ? 'Please pick an email with Google first.'
            : 'Please enter your email address.',
      );
      return;
    }
    // Shape check on the typed path only — a picked address came from a
    // real Google account and has nothing to check.
    if (!AuthPolicy.allowsGoogleEmailPicker &&
        !EmailInputField.looksLikeEmail(email)) {
      CustomSnackbar.error(
        context,
        title: 'Error',
        message: "That email address doesn't look right.",
      );
      return;
    }
    await _sendOtp(recipient: email, isPhone: false);
  }

  /// Non-India phone screen: nothing is sent here. The number is just
  /// validated and kept, and the user moves to the email step, which is
  /// where verification actually happens for learners SMS can't reach.
  void _handleNext() {
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _mode = LoginMode.email);
  }

  /// Opens the native Google account picker so the user can pick a
  /// verified email in one tap instead of typing it (and risking a
  /// typo). Only fills [_emailController] with the pick — sending the
  /// OTP is a separate, explicit "Send OTP" tap.
  Future<void> _handleGooglePickEmail() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    GoogleAccountInfo? account;
    try {
      // The name/photo on the returned account are cached by the
      // service, so Setup Profile can prefill them after the OTP hop
      // if this turns out to be a new user.
      account = await sl<GoogleAccountPickerService>().pickAccount();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(
          context,
          title: 'Error',
          message: 'Could not get your Google account: ${e.toString()}',
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (account != null) {
        _mode = LoginMode.email;
        _emailController.text = account.email;
      }
    });
  }

  /// Shared OTP-send path for both the manual form and the Google
  /// account picker.
  Future<void> _sendOtp({
    required String recipient,
    required bool isPhone,
  }) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Dial code without the leading '+', e.g. "91" from "+91".
    final stdCode = _selectedCountry.dialCode.replaceFirst('+', '');
    final dialCode = _selectedCountry.dialCode;

    try {
      final result = await sl<SendOtpV2UseCase>()(
        recipient: recipient,
        isPhone: isPhone,
        stdCode: isPhone ? stdCode : null,
      );

      result.fold(
        (failure) {
          if (!mounted) return;
          CustomSnackbar.error(
            context,
            title: 'Error',
            message: failure.message,
          );
        },
        (model) {
          if (!mounted) return;
          // status 1 → success (green)
          // status 3 → warning (orange)
          // anything else → error (red)
          if (model.status == 1) {
            CustomSnackbar.success(
              context,
              title: 'Success',
              message: model.message,
            );
          } else if (model.status == 3) {
            CustomSnackbar.warning(
              context,
              title: 'Warning',
              message: model.message,
            );
          } else {
            CustomSnackbar.error(
              context,
              title: 'Error',
              message: model.message,
            );
            return; // Don't navigate on non-success statuses
          }
          // Carry the recipient kind into /otp so resend / verify
          // dispatch to the correct channel. Phone path keeps the
          // legacy `phone=&countryCode=` for any callers still
          // building the URL by hand; email path uses `email=`.
          // On the email leg, carry any number collected on the phone
          // screen first (the non-India "Next" hand-off) so setup-profile
          // can pre-fill it instead of asking twice.
          final carriedPhone = _phoneController.text.trim();
          final query = isPhone
              ? 'phone=$recipient&countryCode=$dialCode&isPhone=true'
              : [
                  'email=${Uri.encodeComponent(recipient)}',
                  'isPhone=false',
                  if (carriedPhone.isNotEmpty) ...[
                    'phone=$carriedPhone',
                    'countryCode=${Uri.encodeComponent(dialCode)}',
                  ],
                ].join('&');
          context.push('${AppRoutes.otp}?$query');
        },
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(
          context,
          title: 'Error',
          message: 'Failed to send OTP: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(AppImages.loginBackground, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: LoginFormContent(
                formKey: _formKey,
                phoneController: _phoneController,
                emailController: _emailController,
                selectedCountry: _selectedCountry,
                mode: _mode,
                isLoading: _isLoading,
                onCountrySelected: (country) {
                  setState(() => _selectedCountry = country);
                },
                onSendOTPPressed: _handleSendOTP,
                onGooglePickEmailPressed: _handleGooglePickEmail,
                onNextPressed: _handleNext,
                onEditPhonePressed: _handleEditPhone,
              ),
            ),
            // Full-screen loading overlay — shown while the OTP is being
            // requested from the backend.
            if (_isLoading)
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
        ),
      ),
    );
  }
}
