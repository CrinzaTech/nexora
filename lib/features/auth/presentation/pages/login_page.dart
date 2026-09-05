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

  void _toggleMode() {
    setState(() {
      _mode = _mode == LoginMode.phone ? LoginMode.email : LoginMode.phone;
    });
    // Reset the form so a previously-typed-but-discarded field doesn't
    // raise a validation error against the now-hidden input.
    _formKey.currentState?.reset();
  }

  Future<void> _handleSendOTP() async {
    if (!mounted) return;

    final isPhone = _mode == LoginMode.phone;
    if (isPhone) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      await _sendOtp(recipient: _phoneController.text.trim(), isPhone: true);
      return;
    }

    // Email mode has no typed field to validate — the recipient only
    // ever comes from a Google account pick, so just guard it's set.
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomSnackbar.error(
        context,
        title: 'Error',
        message: 'Please pick an email with Google first.',
      );
      return;
    }
    await _sendOtp(recipient: email, isPhone: false);
  }

  /// Opens the native Google account picker so the user can pick a
  /// verified email in one tap instead of typing it (and risking a
  /// typo). Only fills [_emailController] with the pick — sending the
  /// OTP is a separate, explicit "Send OTP" tap.
  Future<void> _handleGooglePickEmail() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    String? email;
    try {
      email = await sl<GoogleAccountPickerService>().pickEmail();
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
      if (email != null) {
        _mode = LoginMode.email;
        _emailController.text = email;
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
          final query = isPhone
              ? 'phone=$recipient&countryCode=$dialCode&isPhone=true'
              : 'email=${Uri.encodeComponent(recipient)}&isPhone=false';
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
                onToggleMode: _toggleMode,
                onSendOTPPressed: _handleSendOTP,
                onGooglePickEmailPressed: _handleGooglePickEmail,
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
