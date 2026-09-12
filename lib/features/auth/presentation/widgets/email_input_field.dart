import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Typed-email counterpart to [GoogleEmailPickerField], used where the
/// Google account picker isn't offered (iOS — see [AuthPolicy]).
///
/// Deliberately the same 52pt pill as the picker and the phone field, so
/// toggling login mode doesn't shift the form under the user's thumb.
///
/// The email it collects goes down exactly the same OTP path as a picked
/// one — the backend only ever receives a string — so an account created
/// through the Google shortcut on Android signs in here without anything
/// special.
class EmailInputField extends StatelessWidget {
  const EmailInputField({
    super.key,
    required this.controller,
    required this.enabled,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

  /// Deliberately loose. The OTP send is the real check — a code that
  /// never arrives tells the user their address was wrong far more
  /// reliably than a regex arguing about what an address may contain.
  /// This only catches the obvious typo before a wasted round trip.
  static bool looksLikeEmail(String value) {
    final trimmed = value.trim();
    final at = trimmed.indexOf('@');
    if (at <= 0 || at != trimmed.lastIndexOf('@')) return false;
    final domain = trimmed.substring(at + 1);
    return domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.') &&
        !trimmed.contains(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Screen.getVerticalSize(52),
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        // Lets iOS offer the address from the device's own account,
        // which gets most of the picker's convenience back for free.
        autofillHints: const [AutofillHints.email],
        inputFormatters: [
          // A space in an email address is always a mistake, and the
          // iOS keyboard is happy to insert one after autocomplete.
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        onFieldSubmitted: (_) => onSubmitted?.call(),
        style: AppTypography.bodyTextLargeSemiBold.copyWith(
          color: AppColors.textPrimary,
          fontSize: Screen.getFontSizeCapped(15),
          letterSpacing: -0.01,
        ),
        decoration: InputDecoration(
          hintText: 'Enter your email address',
          hintStyle: AppTypography.bodyTextLargeMedium.copyWith(
            color: AppColors.mutedTextPrimary,
            fontSize: Screen.getFontSizeCapped(14),
            letterSpacing: -0.01,
          ),
          filled: true,
          fillColor: AppColors.white,
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            color: AppColors.mutedTextPrimary,
            size: Screen.getSize(20),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: Screen.getHorizontalSize(16),
          ),
          border: _border(AppColors.grey200),
          enabledBorder: _border(AppColors.grey200),
          focusedBorder: _border(AppColors.primary),
          disabledBorder: _border(AppColors.grey200),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(50),
    borderSide: BorderSide(color: color, width: 1),
  );
}
