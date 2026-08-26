import 'dart:io';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/core/network/token_refresh_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:nexora/core/widgets/logout_dialog.dart';
import 'package:nexora/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:nexora/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:flutter/material.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Setup Profile Screen
/// Displayed when a user tries to login but is not registered yet.
///
/// Two entry shapes:
///   • Phone signup → [phoneNumber] is set, [email] is empty,
///     [isPhone] is true. User completes signup by filling email
///     (editable) + name + gender.
///   • Email signup → [email] is set + verified, [isPhone] is false.
///     User completes signup by filling phone (editable) + name +
///     gender. The verified email is shown but locked.
class SetupProfilePage extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final String email;
  final bool isPhone;

  const SetupProfilePage({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
    this.email = '',
    this.isPhone = true,
  });

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // Used only in the email-signup branch — the user types their phone
  // here so the profile lands with both contact channels populated.
  // Lives at top-level state so the controller's text survives
  // rebuilds even when the field is conditionally rendered.
  final _phoneController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  File? _profileImage;

  /// Guards against a second `pickImage` while the first is still
  /// opening. The platform channel behind [ImagePicker] is a
  /// singleton regardless of how many Dart instances we construct,
  /// so a double-tap on the avatar throws
  /// `PlatformException(already_active)`.
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    // Email-signup entry: pre-fill the email field with the verified
    // address so the user can see it (and so the locked field shows
    // a value, not a placeholder).
    if (!widget.isPhone && widget.email.isNotEmpty) {
      _emailController.text = widget.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (!mounted || picked == null) return;
      setState(() => _profileImage = File(picked.path));
    } on PlatformException catch (e) {
      // `already_active` (a racing pick) and a denied gallery permission
      // both land here. Neither is worth a crash report — the user simply
      // ends up without a new photo and can tap again.
      debugPrint('Profile image pick failed: ${e.code}');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // Built from the active brightness, not pinned to light —
            // otherwise the picker stays a white sheet with black text
            // in dark mode. onPrimary is the label on the selected day,
            // which sits on AppColors.primary in both themes.
            colorScheme:
                (AppColors.isDark
                        ? const ColorScheme.dark()
                        : const ColorScheme.light())
                    .copyWith(
                      primary: AppColors.primary,
                      onPrimary: AppColors.alwaysWhite,
                      surface: AppColors.white,
                      onSurface: AppColors.textPrimary,
                    ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime? date) => Utils.formatDdMmmYyyy(date);

  int _genderToInt(String gender) {
    switch (gender) {
      case 'Male':
        return 1;
      case 'Female':
        return 2;
      default:
        return 0;
    }
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleContinue(
    Function startLoading,
    Function stopLoading,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    // DOB + profile photo are optional now — only gender stays
    // required because the API still expects a non-null gender enum.
    // Image / dob arguments to the use case are null-safe (see
    // UpdateProfileUseCase signature), so passing them through as
    // null when the user skipped them is the correct shape.
    if (_selectedGender == null) {
      CustomSnackbar.warning(
        context,
        title: 'Gender Required',
        message: 'Please select your gender to continue.',
      );
      return;
    }

    startLoading();

    // Phone vs email branch decides which side carries the verified
    // value and which side reads from the user's input. The opposite
    // channel is left to whatever the user typed (or empty when the
    // email-signup user skipped phone) — backend treats empty as
    // "not set yet".
    final phoneToSend = widget.isPhone
        ? widget.phoneNumber
        : _phoneController.text.trim();
    final emailToSend = widget.isPhone
        ? _emailController.text.trim()
        : widget.email;

    final result = await sl<UpdateProfileUseCase>()(
      name: _nameController.text.trim(),
      phoneNumber: phoneToSend.isEmpty ? null : phoneToSend,
      email: emailToSend.isEmpty ? null : emailToSend,
      dob: _selectedDate != null ? _formatDateForApi(_selectedDate!) : null,
      gender: _genderToInt(_selectedGender!),
      userProfileImage: _profileImage,
    );

    stopLoading();

    if (!mounted) return;

    result.fold(
      (failure) {
        CustomSnackbar.error(
          context,
          title: 'Profile Setup Failed',
          message: failure.message,
        );
      },
      (profile) async {
        await sl<SessionService>().saveProfileComplete(true);
        if (!mounted) return;
        CustomSnackbar.success(
          context,
          title: 'Success',
          message: 'Profile created successfully.',
        );
        context.go(AppRoutes.dashboard);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await LogoutDialog.show(context);
        if (confirmed == true && context.mounted) {
          await sl<ContentCompletionService>().clearForLogout();
          // Revoke server-side first — it needs the refresh token that
          // clearToken deletes.
          await sl<TokenRefreshService>().revokeSession();
          await sl<SessionService>().clearToken();
          if (context.mounted) context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        body: Container(
          width: Screen.width,
          height: Screen.height,
          decoration: BoxDecoration(
            color: AppColors.white,
            // image: DecorationImage(
            //   image: AssetImage(AppImages.accountSetupBackground),
            //   fit: BoxFit.cover,
            // ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: Screen.getPadding(horizontal: 5),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () async {
                          final confirmed = await LogoutDialog.show(context);
                          if (confirmed == true && context.mounted) {
                            await sl<ContentCompletionService>()
                                .clearForLogout();
                            await sl<TokenRefreshService>().revokeSession();
                            await sl<SessionService>().clearToken();
                            if (context.mounted) context.go(AppRoutes.login);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Setup your Profile',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h5SemiBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveHelper.of(
                            context,
                          ).maxContentWidth,
                        ),
                        child: Padding(
                          padding: Screen.getPadding(all: AppSizes.paddingL),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Profile Picture
                                _ProfilePicturePicker(
                                  image: _profileImage,
                                  onTap: _pickImage,
                                ),
                                SizedBox(height: Screen.getVerticalSize(24)),

                                // Full Name
                                const _FormLabel(label: 'Full Name'),
                                SizedBox(height: Screen.getVerticalSize(8)),
                                CustomTextFormField(
                                  controller: _nameController,
                                  hintText: 'Enter here',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    return null;
                                  },
                                ),

                                SizedBox(height: Screen.getVerticalSize(16)),

                                // Email — locked + pre-filled when the user
                                // signed up via email (it's already verified),
                                // editable + required when they signed up
                                // via phone.
                                _FormLabel(
                                  label: widget.isPhone
                                      ? 'Email Address'
                                      : 'Email Address (verified)',
                                ),
                                SizedBox(height: Screen.getVerticalSize(8)),
                                CustomTextFormField(
                                  controller: _emailController,
                                  hintText: 'Enter here',
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: widget.isPhone,
                                  validator: (value) {
                                    // Skip validation entirely on the locked
                                    // branch — the value comes from the
                                    // verified-email pipeline so it's
                                    // trustworthy by construction.
                                    if (!widget.isPhone) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: Screen.getVerticalSize(16)),

                                // Phone — only collected for the email-signup
                                // branch. Optional: empty value is fine, the
                                // user can add a phone later via edit-profile.
                                if (!widget.isPhone) ...[
                                  const _FormLabel(label: 'Phone Number'),
                                  SizedBox(height: Screen.getVerticalSize(8)),
                                  PhoneInputField(controller: _phoneController),
                                  SizedBox(height: Screen.getVerticalSize(16)),
                                ],

                                // Date of Birth
                                const _FormLabel(label: 'Date of Birth'),
                                SizedBox(height: Screen.getVerticalSize(8)),
                                _DateField(
                                  selectedDate: _selectedDate,
                                  onTap: () => _selectDate(context),
                                  formatDate: _formatDate,
                                ),

                                SizedBox(height: Screen.getVerticalSize(16)),
                                // Gender
                                const _FormLabel(label: 'Gender'),
                                SizedBox(height: Screen.getVerticalSize(10)),
                                _GenderSelector(
                                  selectedGender: _selectedGender,
                                  onGenderChanged: (gender) {
                                    setState(() => _selectedGender = gender);
                                  },
                                ),
                                SizedBox(height: Screen.getVerticalSize(36)),

                                // Continue Button
                                SizedBox(
                                  child: CustomActionButton(
                                    onTap:
                                        (startLoading, stopLoading, btnState) {
                                          _handleContinue(
                                            startLoading,
                                            stopLoading,
                                          );
                                        },
                                    name: 'Continue',
                                    isFormFilled: true,
                                  ),
                                ),
                                SizedBox(height: Screen.getVerticalSize(24)),
                              ],
                            ),
                          ),
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────
// Profile Picture Picker
// ─────────────────────────────────────────────────────────────
class _ProfilePicturePicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;

  const _ProfilePicturePicker({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: AppColors.grey200.withValues(alpha: 0.5),
            backgroundImage: image != null ? FileImage(image!) : null,
            child: image == null
                ? Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.grey300.withValues(alpha: 0.8),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.alwaysWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Form Label
// ─────────────────────────────────────────────────────────────
class _FormLabel extends StatelessWidget {
  final String label;

  const _FormLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Date Field — styled to match CustomTextFormField
// ─────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final String Function(DateTime?) formatDate;

  const _DateField({
    required this.selectedDate,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFilled = selectedDate != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.white,
          prefix: const SizedBox(width: 4),
          suffixIcon: Icon(
            Icons.calendar_month_outlined,
            color: AppColors.grey400,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: isFilled ? AppColors.primary : AppColors.grey300,
            ),
          ),
        ),
        child: Text(
          formatDate(selectedDate),
          style: AppTypography.bodyTextLargeMedium.copyWith(
            color: isFilled ? AppColors.textPrimary : AppColors.grey500,
            fontSize: Screen.getFontSize(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Gender Selector
// ─────────────────────────────────────────────────────────────
class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String) onGenderChanged;

  const _GenderSelector({
    required this.selectedGender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Screen.getHorizontalSize(10),
      runSpacing: Screen.getVerticalSize(10),
      children: [
        _GenderOption(
          label: 'Male',
          isSelected: selectedGender == 'Male',
          onTap: () => onGenderChanged('Male'),
        ),
        _GenderOption(
          label: 'Female',
          isSelected: selectedGender == 'Female',
          onTap: () => onGenderChanged('Female'),
        ),
        _GenderOption(
          label: 'Other',
          isSelected: selectedGender == 'Other',
          onTap: () => onGenderChanged('Other'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Gender Option
// ─────────────────────────────────────────────────────────────
class _GenderOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSizes.borderRadiusCircle,
      child: Container(
        height: Screen.getVerticalSize(45),
        padding: Screen.getPadding(
          horizontal: AppSizes.paddingM,
          vertical: AppSizes.paddingXS,
        ),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.6),
          borderRadius: AppSizes.borderRadiusCircle,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.grey300,
                  width: isSelected ? 5 : 1.5,
                ),
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(8)),
            Text(
              label,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
