import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_action_button.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:nexora/core/widgets/profile_image_viewer.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Edit Profile screen.
///
/// Mirrors the layout of [SetupProfilePage] but pre-populates every field
/// from the supplied [profile]. Tracks edits locally and only fires
/// `PUT /user-profile` when at least one field changed — pressing Save with
/// no edits just shows a success snackbar and pops.
class EditProfilePage extends StatefulWidget {
  final UserProfileModel profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  // Local form state.
  DateTime? _selectedDate;
  String? _selectedGender; // 'Male' | 'Female' | 'Other'
  File? _newProfileImage;

  /// Guards against a second `pickImage` while the first is still
  /// opening — see the same flag in `SetupProfilePage`.
  bool _isPickingImage = false;

  // Snapshots of the values we received on open — used for the dirty
  // check on save so we can skip the API call when nothing changed.
  late final String _originalName;
  late final String _originalEmail;
  late final String _originalPhone;
  late final DateTime? _originalDate;
  late final String? _originalGender;

  /// `true` when the field already had a server-side value when the page
  /// opened — those fields are rendered read-only so the user can't
  /// overwrite a previously-set email / phone / name. Empty fields stay
  /// editable so a partially-set profile can still finish onboarding.
  late final bool _emailLocked;
  late final bool _phoneLocked;
  late final bool _isNameLocked;
  late final bool _isDobLocked;
  late final bool _isGenderLocked;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _originalName = p.name ?? '';
    _originalEmail = p.email ?? '';
    _originalPhone = p.phoneNumber ?? '';
    _originalDate = _parseDob(p.dob);
    _originalGender = _genderToLabel(p.gender);

    _emailLocked = _originalEmail.trim().isNotEmpty;
    _phoneLocked = _originalPhone.trim().isNotEmpty;
    _isNameLocked = _originalName.trim().isNotEmpty;
    _isDobLocked = _originalDate != null;
    _isGenderLocked = (_originalGender?.trim().isNotEmpty ?? false);

    _nameController = TextEditingController(text: _originalName);
    _emailController = TextEditingController(text: _originalEmail);
    _phoneController = TextEditingController(text: _originalPhone);
    _selectedDate = _originalDate;
    _selectedGender = _originalGender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  DateTime? _parseDob(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String? _genderToLabel(Gender? g) {
    switch (g) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      case null:
        return null;
    }
  }

  int _genderLabelToInt(String label) {
    switch (label) {
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

  bool get _isDirty {
    if (_newProfileImage != null) return true;
    if (_nameController.text.trim() != _originalName.trim()) return true;
    if (_emailController.text.trim() != _originalEmail.trim()) return true;
    if (_phoneController.text.trim() != _originalPhone.trim()) return true;
    if (_selectedDate != _originalDate) return true;
    if (_selectedGender != _originalGender) return true;
    return false;
  }

  // ────────────────────────────────────────────────────────────
  // Pickers
  // ────────────────────────────────────────────────────────────

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
      setState(() => _newProfileImage = File(picked.path));
    } on PlatformException catch (e) {
      debugPrint('Profile image pick failed: ${e.code}');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Save
  // ────────────────────────────────────────────────────────────

  /// True when the user has *some* image — either a freshly-picked file
  /// or an existing remote URL on the loaded profile.
  bool get _hasProfileImage {
    if (_newProfileImage != null) return true;
    final remote = widget.profile.userProfileImage;
    return remote != null && remote.isNotEmpty;
  }

  /// Tracks whether the in-page Save button is currently animating its
  /// loading state. We drive it from the cubit's [ProfileState.updating]
  /// transitions instead of toggling locally, so the UI mirrors the
  /// shared cubit lifecycle.
  Function? _stopLoading;

  Future<void> _handleSave(Function startLoading, Function stopLoading) async {
    if (!_formKey.currentState!.validate()) return;

    // DOB and profile image are both optional — proceed as long as gender is set.

    if (_selectedGender == null) {
      CustomSnackbar.warning(
        context,
        title: 'Gender Required',
        message: 'Please select your gender.',
      );
      return;
    }

    // Nothing changed → no API call, but still acknowledge the tap so the
    // user gets feedback (per the spec).
    if (!_isDirty) {
      CustomSnackbar.success(
        context,
        title: 'No changes',
        message: 'Your profile is already up to date.',
      );
      Navigator.of(context).maybePop();
      return;
    }

    startLoading();
    _stopLoading = stopLoading;

    // Send the optional fields only when the user actually has something
    // to save in them — empty strings would otherwise wipe the value
    // server-side.
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // Route through the shared cubit so Home + Profile pages observe the
    // refreshed profile via their BlocBuilders without manual refetches.
    await context.read<ProfileCubit>().updateProfile(
      name: _nameController.text.trim(),
      phoneNumber: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      dob: _selectedDate != null ? _formatDateForApi(_selectedDate!) : null,
      gender: _genderLabelToInt(_selectedGender!),
      userProfileImage: _newProfileImage,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CustomAppBar(
        title: 'Edit Profile',
        centerTitle: true,
        titleColor: AppColors.textPrimary,
      ),
      body: BlocListener<ProfileCubit, ProfileState>(
        // Only react to terminal transitions of the *update* — ignore
        // background loads/refreshes (those happen on Profile/Home pages
        // and shouldn't dismiss this form).
        listenWhen: (prev, curr) {
          final wasUpdating = prev.maybeWhen(
            updating: (_) => true,
            orElse: () => false,
          );
          if (!wasUpdating) return false;
          return curr.maybeWhen(
            updated: (_) => true,
            error: (_) => true,
            orElse: () => false,
          );
        },
        listener: (context, state) {
          _stopLoading?.call();
          _stopLoading = null;
          state.maybeWhen(
            updated: (_) {
              CustomSnackbar.success(
                context,
                title: 'Profile updated',
                message: 'Your changes have been saved.',
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            error: (message) {
              CustomSnackbar.error(
                context,
                title: 'Update failed',
                message: message,
              );
            },
            orElse: () {},
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: Screen.getPadding(all: AppSizes.paddingL),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.of(context).maxContentWidth,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _ProfilePicturePicker(
                        newImage: _newProfileImage,
                        existingImageUrl: widget.profile.userProfileImage,
                        profileName: _nameController.text.trim(),
                        onTap: _pickImage,
                      ),
                      SizedBox(height: Screen.getVerticalSize(24)),

                      // Name is intentionally locked once the user has
                      // set it the first time — onboarding records it
                      // during setup-profile, after which it becomes
                      // read-only on this edit screen. `enabled: false`
                      // disables input + flips the field's fill to
                      // grey100 so the lock is visually unmistakable.
                      _FormLabel(
                        label: _isNameLocked ? 'Full Name' : 'Full Name',
                      ),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      CustomTextFormField(
                        controller: _nameController,
                        hintText: 'Enter here',
                        enabled: !_isNameLocked,
                        suffixIcon: _isNameLocked
                            ? Icon(Icons.lock_rounded)
                            : null,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name is too short';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: Screen.getVerticalSize(16)),

                      const _FormLabel(label: 'Email Address'),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      CustomTextFormField(
                        controller: _emailController,
                        hintText: _emailLocked
                            ? 'Already on file'
                            : 'Enter here (optional)',
                        keyboardType: TextInputType.emailAddress,
                        // Locked when the backend already has an email — user
                        // can't overwrite a previously-set address.
                        enabled: !_emailLocked,
                        suffixIcon: _emailLocked
                            ? Icon(Icons.lock_rounded)
                            : null,
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          // Optional — empty is fine.
                          if (v.isEmpty) return null;
                          if (!Utils.isValidEmail(v)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: Screen.getVerticalSize(16)),

                      const _FormLabel(label: 'Phone Number'),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      CustomTextFormField(
                        controller: _phoneController,
                        hintText: _phoneLocked
                            ? 'Already on file'
                            : 'Enter here (optional)',
                        keyboardType: TextInputType.phone,
                        // Locked when the backend already has a phone — same
                        // policy as the email field above.
                        enabled: !_phoneLocked,
                        suffixIcon: _phoneLocked
                            ? Icon(Icons.lock_rounded)
                            : null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return null;
                          if (!Utils.isValidPhoneNumber(v)) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: Screen.getVerticalSize(16)),

                      _FormLabel(
                        label: _isDobLocked ? 'Date of Birth' : 'Date of Birth',
                      ),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      if (_isDobLocked)
                        CustomTextFormField(
                          controller: TextEditingController(
                            text: _selectedDate != null
                                ? Utils.formatDdMmmYyyy(_selectedDate)
                                : '',
                          ),
                          enabled: false,
                          suffixIcon: const Icon(Icons.lock_rounded),
                        )
                      else
                        _DateField(
                          selectedDate: _selectedDate,
                          onTap: _selectDate,
                          formatDate: Utils.formatDdMmmYyyy,
                        ),

                      SizedBox(height: Screen.getVerticalSize(16)),

                      _FormLabel(label: _isGenderLocked ? 'Gender' : 'Gender'),
                      SizedBox(height: Screen.getVerticalSize(8)),
                      if (_isGenderLocked)
                        CustomTextFormField(
                          controller: TextEditingController(
                            text: _selectedGender ?? '',
                          ),
                          enabled: false,
                          suffixIcon: const Icon(Icons.lock_rounded),
                        )
                      else
                        _GenderSelector(
                          selectedGender: _selectedGender,
                          onGenderChanged: (g) =>
                              setState(() => _selectedGender = g),
                        ),
                      SizedBox(height: Screen.getVerticalSize(24)),

                      if (_isNameLocked ||
                          _emailLocked ||
                          _phoneLocked ||
                          _isDobLocked ||
                          _isGenderLocked)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: Screen.getVerticalSize(24),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.grey500,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please contact the app owner to modify your details.',
                                  style: AppTypography.bodyTextMedium.copyWith(
                                    color: AppColors.grey500,
                                    fontSize: Screen.getFontSize(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      CustomActionButton(
                        onTap: (startLoading, stopLoading, _) =>
                            _handleSave(startLoading, stopLoading),
                        name: 'Save Changes',
                        isFormFilled: true,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Local-private widgets — copied from setup_profile_page so this
// page is self-contained. If a third caller needs them they can be
// promoted into a shared profile/widgets file.
// ─────────────────────────────────────────────────────────────

class _ProfilePicturePicker extends StatelessWidget {
  final File? newImage;
  final String? existingImageUrl;
  final String profileName;
  final VoidCallback onTap;

  const _ProfilePicturePicker({
    required this.newImage,
    required this.existingImageUrl,
    required this.profileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasNew = newImage != null;
    final hasRemote = existingImageUrl != null && existingImageUrl!.isNotEmpty;
    final hasImage = hasNew || hasRemote;

    return Stack(
      children: [
        // Tapping the picture itself previews it full-screen; the edit
        // badge (below) is the only way to launch the image picker, so
        // "view" and "change" don't fight over the same tap target.
        GestureDetector(
          onTap: hasImage
              ? () => showProfileImageViewer(
                  context,
                  imageFile: newImage,
                  imageUrl: hasNew ? null : existingImageUrl,
                )
              : null,
          child: ProfileImageHero(
            tag: hasImage ? kProfileImageHeroTag : null,
            child: hasImage
                ? CircleAvatar(
                    radius: 55,
                    backgroundColor: AppColors.grey200.withValues(alpha: 0.5),
                    backgroundImage: hasNew
                        ? FileImage(newImage!) as ImageProvider
                        : CachedNetworkImageProvider(
                            existingImageUrl!,
                            cacheKey: Utils.imageCacheKey(existingImageUrl!),
                          ),
                  )
                : Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.6),
                          AppColors.primary.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      Utils.getInitials(profileName.isEmpty ? '?' : profileName),
                      style: AppTypography.h6SemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                        fontSize: Screen.getFontSize(36),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.alwaysWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final ValueChanged<String> onGenderChanged;

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
