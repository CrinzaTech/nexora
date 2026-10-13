import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/data/services/store_location_service.dart';
import 'package:nexora/features/store/presentation/bloc/store_address_form_cubit.dart';
import 'package:nexora/features/store/presentation/widgets/store_address_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Add (A3) or edit (A4) a delivery address. Pops with the saved address.
///
/// The checks mirror the server's (STORE_API.md §5) so a learner hears
/// about a bad pincode before a round trip, not after; the server still
/// has the last word and its message is shown when it disagrees.
class StoreAddressFormPage extends StatelessWidget {
  final StoreAddress? address;

  const StoreAddressFormPage({super.key, this.address});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoreAddressFormCubit>()..loadStates(),
      child: _FormView(address: address),
    );
  }
}

class _FormView extends StatefulWidget {
  final StoreAddress? address;

  const _FormView({this.address});

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.address?.fullName);
  late final _phone = TextEditingController(text: widget.address?.phone);
  late final _line1 = TextEditingController(text: widget.address?.line1);
  late final _line2 = TextEditingController(text: widget.address?.line2);
  late final _landmark = TextEditingController(text: widget.address?.landmark);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _pincode = TextEditingController(text: widget.address?.pincode);
  late String? _stateCode = widget.address?.stateCode;
  late String? _stateName = widget.address?.stateName;
  late StoreAddressType _type = widget.address?.type ?? StoreAddressType.home;
  // The server makes the first address the default on its own.
  late bool _isDefault = widget.address?.isDefault ?? false;
  bool _stateMissing = false;
  bool _submitted = false;

  /// Set once "Use my current location" filled the form, to remind the
  /// learner GPS can't know their flat number.
  bool _filledFromLocation = false;

  bool get _editing => widget.address != null;

  @override
  void initState() {
    super.initState();
    // A new address starts with the learner's own name and number — most
    // people ship to themselves. Editing keeps what was saved.
    if (!_editing) {
      final profileCubit = context.read<ProfileCubit>();
      final profile = _profileOf(profileCubit.state);
      if (profile != null) {
        _prefillFromProfile(profile);
      } else {
        // Not fetched yet (or it failed): the listener below fills in
        // when it arrives.
        profileCubit.state.maybeWhen(
          loading: () {},
          orElse: profileCubit.loadProfile,
        );
      }
    }
  }

  static UserProfileModel? _profileOf(ProfileState state) => state.maybeWhen(
    loaded: (p) => p,
    updating: (p) => p,
    updated: (p) => p,
    orElse: () => null,
  );

  /// Fills only fields the learner hasn't typed into.
  void _prefillFromProfile(UserProfileModel profile) {
    final name = profile.name?.trim() ?? '';
    if (_name.text.trim().isEmpty && name.length >= 2) {
      _name.text = name.length > 100 ? name.substring(0, 100) : name;
    }
    final phone = _indianMobile(profile.phoneNumber);
    if (_phone.text.trim().isEmpty && phone != null) _phone.text = phone;
  }

  /// The profile's number as 10 digits, only when it is plainly an Indian
  /// mobile: bare, `+91…`, `91…` or `0…`. Anything else (a foreign
  /// number, an email-only account) leaves the field for the learner.
  static String? _indianMobile(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _line1,
      _line2,
      _landmark,
      _city,
      _pincode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation (same rules as the API) ─────────────────────────────

  static String? _length(String? v, String what, int min, int max) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter $what';
    if (s.length < min) return '$what is too short';
    if (s.length > max) return 'Keep $what under $max characters';
    return null;
  }

  static String? _optional(String? v, String what, int max) {
    final s = v?.trim() ?? '';
    return s.length > max ? 'Keep $what under $max characters' : null;
  }

  /// "+91 98765 43210" is fine: the last 10 digits are what's kept.
  static String _phoneDigits(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static String? _validatePhone(String? v) {
    final digits = _phoneDigits(v ?? '');
    if (digits.isEmpty) return 'Enter a mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? _validatePincode(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter the pincode';
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(s)) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }

  Future<void> _pickState(List<StoreGstState> states) async {
    FocusScope.of(context).unfocus();
    final picked = await showStoreSheet<StoreGstState>(
      context,
      title: 'Select state',
      builder: (sheetContext) =>
          _StatePicker(states: states, selectedCode: _stateCode),
    );
    if (picked != null) {
      setState(() {
        _stateCode = picked.code;
        _stateName = picked.name;
        _stateMissing = false;
      });
    }
  }

  Future<void> _useLocation() async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<StoreAddressFormCubit>();
    final result = await cubit.locate();
    if (!mounted) return;
    await result.fold(_onLocateError, (found) async {
      // The state is matched against A1's list, so make sure it's there.
      if (cubit.state.states.isEmpty) await cubit.loadStates();
      if (!mounted) return;
      final gst = cubit.matchState(found.stateName);
      void put(TextEditingController c, String? v) {
        if (v != null && v.isNotEmpty) c.text = v;
      }

      setState(() {
        put(_line1, found.line1);
        put(_line2, found.area);
        put(_city, found.city);
        put(_pincode, found.pincode);
        if (gst != null) {
          _stateCode = gst.code;
          _stateName = gst.name;
          _stateMissing = false;
        }
        _filledFromLocation = true;
      });
      final filledAnything =
          found.line1 != null ||
          found.city != null ||
          found.pincode != null ||
          gst != null;
      if (filledAnything) {
        CustomSnackbar.success(
          context,
          title: 'Address filled',
          message: 'Add your flat or house number and check the details.',
        );
      } else {
        CustomSnackbar.warning(
          context,
          title: 'Couldn’t read an address here',
          message: 'Please fill in the form.',
        );
      }
    });
  }

  Future<void> _onLocateError(StoreLocateError error) async {
    final service = context.read<StoreAddressFormCubit>().locationService;
    switch (error) {
      case StoreLocateError.serviceOff:
        final open = await showStoreConfirm(
          context,
          title: 'Location is turned off',
          message: 'Turn on location to fill your address in one tap.',
          confirmLabel: 'Turn on',
        );
        if (open) await service.openLocationSettings();
      case StoreLocateError.deniedForever:
        final open = await showStoreConfirm(
          context,
          title: 'Allow location access',
          message:
              'Location is blocked for this app. Allow it in Settings, or '
              'fill in the address yourself.',
          confirmLabel: 'Open Settings',
        );
        if (open) await service.openAppSettings();
      case StoreLocateError.denied:
        CustomSnackbar.info(
          context,
          title: 'No problem',
          message: 'You can fill in the address yourself.',
        );
      case StoreLocateError.outsideIndia:
        CustomSnackbar.warning(
          context,
          title: 'Outside India',
          message: 'The store delivers to addresses in India only.',
        );
      case StoreLocateError.notFound:
        CustomSnackbar.error(
          context,
          title: 'Couldn’t find your address',
          message: 'Check your connection, or fill in the form.',
        );
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _stateMissing = _stateCode == null;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _stateCode == null) return;
    FocusScope.of(context).unfocus();
    final saved = await context.read<StoreAddressFormCubit>().save(
      StoreAddressInput(
        fullName: _name.text,
        phone: _phoneDigits(_phone.text),
        line1: _line1.text,
        line2: _line2.text,
        landmark: _landmark.text,
        city: _city.text,
        stateCode: _stateCode!,
        pincode: _pincode.text,
        type: _type,
        isDefault: _isDefault,
      ),
      id: widget.address?.id,
    );
    if (saved != null && mounted) context.pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (_, next) => !_editing && _profileOf(next) != null,
      listener: (_, state) =>
          setState(() => _prefillFromProfile(_profileOf(state)!)),
      child: _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return BlocBuilder<StoreAddressFormCubit, StoreAddressFormState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldLight,
          appBar: CustomAppBar(
            title: _editing ? 'Edit address' : 'Add delivery address',
          ),
          body: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _UseLocationCard(
                  loading: state.locating,
                  filled: _filledFromLocation,
                  onTap: _useLocation,
                ),
                StorePanel(
                  title: 'Contact',
                  child: Column(
                    children: [
                      _Field(
                        label: 'Full name',
                        controller: _name,
                        icon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _length(v, 'your name', 2, 100),
                      ),
                      _Field(
                        label: 'Mobile number',
                        controller: _phone,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        prefixText: '+91 ',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        validator: _validatePhone,
                        last: true,
                      ),
                    ],
                  ),
                ),
                StorePanel(
                  title: 'Address',
                  child: Column(
                    children: [
                      _Field(
                        label: 'Flat, house no., building, street',
                        controller: _line1,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _length(v, 'the address', 5, 200),
                      ),
                      _Field(
                        label: 'Area, locality (optional)',
                        controller: _line2,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _optional(v, 'this line', 200),
                      ),
                      _Field(
                        label: 'Landmark (optional)',
                        controller: _landmark,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _optional(v, 'the landmark', 100),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'City',
                              controller: _city,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => _length(v, 'the city', 2, 100),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Pincode',
                              controller: _pincode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: _validatePincode,
                            ),
                          ),
                        ],
                      ),
                      _StateSelector(
                        stateName: _stateName,
                        loading: state.loadingStates,
                        error: state.statesError,
                        missing: _stateMissing,
                        onTap: state.states.isEmpty
                            ? context.read<StoreAddressFormCubit>().loadStates
                            : () => _pickState(state.states),
                      ),
                    ],
                  ),
                ),
                StorePanel(
                  title: 'Save as',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in StoreAddressType.values)
                            ChoiceChip(
                              avatar: Icon(
                                StoreAddressSummary.iconFor(t),
                                size: 16,
                                color: _type == t
                                    ? AppColors.onPrimary
                                    : AppColors.textSecondary,
                              ),
                              label: Text(t.label),
                              selected: _type == t,
                              showCheckmark: false,
                              labelStyle: AppTypography.bodyTextSmallSemiBold
                                  .copyWith(
                                    color: _type == t
                                        ? AppColors.onPrimary
                                        : AppColors.textPrimary,
                                  ),
                              selectedColor: AppColors.primaryFill,
                              backgroundColor: AppColors.grey100,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) => setState(() => _type = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isDefault,
                        activeTrackColor: AppColors.primaryFill,
                        onChanged: (v) => setState(() => _isDefault = v),
                        title: Text(
                          'Make this my default address',
                          style: AppTypography.bodyTextSemiBold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.saveError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StoreIssueText(message: state.saveError!),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: StoreBottomBar(
            child: StorePrimaryButton(
              label: _editing ? 'Save changes' : 'Save address',
              loading: state.saving,
              onPressed: _save,
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?) validator;
  final String? prefixText;
  final bool last;

  const _Field({
    required this.label,
    required this.controller,
    required this.validator,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.prefixText,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide(color: color, width: width),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        validator: validator,
        textInputAction: TextInputAction.next,
        style: AppTypography.bodyTextLargeMedium,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.mutedTextPrimary,
          ),
          floatingLabelStyle: AppTypography.bodyTextSmallSemiBold.copyWith(
            color: AppColors.primary,
          ),
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: AppColors.grey400),
          prefixText: prefixText,
          prefixStyle: AppTypography.bodyTextLargeMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.inputFillLight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: border(AppColors.transparent),
          enabledBorder: border(AppColors.transparent),
          focusedBorder: border(AppColors.primary, 1.4),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error, 1.4),
          errorMaxLines: 2,
        ),
      ),
    );
  }
}

class _StateSelector extends StatelessWidget {
  final String? stateName;
  final bool loading;
  final String? error;
  final bool missing;
  final VoidCallback onTap;

  const _StateSelector({
    required this.stateName,
    required this.loading,
    required this.error,
    required this.missing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    if (stateName != null) {
      text = stateName!;
    } else if (loading) {
      text = 'Loading states…';
    } else if (error != null) {
      text = 'Couldn’t load states. Tap to retry.';
    } else {
      text = 'Select state';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.inputFillLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            onTap: loading ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: missing ? AppColors.error : AppColors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 20, color: AppColors.grey400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: stateName != null
                          ? AppTypography.bodyTextLargeMedium
                          : AppTypography.bodyTextMedium.copyWith(
                              color: error != null
                                  ? AppColors.error
                                  : AppColors.mutedTextPrimary,
                            ),
                    ),
                  ),
                  loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.grey400,
                        ),
                ],
              ),
            ),
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(
              'Select your state',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Searchable list of states and UTs.
class _StatePicker extends StatefulWidget {
  final List<StoreGstState> states;
  final String? selectedCode;

  const _StatePicker({required this.states, this.selectedCode});

  @override
  State<_StatePicker> createState() => _StatePickerState();
}

class _StatePickerState extends State<_StatePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.states
        : widget.states.where((s) => s.name.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: AppTypography.bodyTextLargeMedium,
              decoration: InputDecoration(
                hintText: 'Search state',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                filled: true,
                fillColor: AppColors.grey100,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final s = shown[i];
                final selected = s.code == widget.selectedCode;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(s),
                  title: Text(
                    s.name,
                    style: selected
                        ? AppTypography.bodyTextLargeBold.copyWith(
                            color: AppColors.primary,
                          )
                        : AppTypography.bodyTextLargeMedium,
                  ),
                  subtitle: s.isUnionTerritory
                      ? Text(
                          'Union territory',
                          style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                            color: AppColors.mutedTextPrimary,
                          ),
                        )
                      : null,
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Use my current location" — fills street, area, city, pincode and
/// state in one tap.
class _UseLocationCard extends StatelessWidget {
  final bool loading;
  final bool filled;
  final VoidCallback onTap;

  const _UseLocationCard({
    required this.loading,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              onTap: loading ? null : onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryFill,
                        boxShadow: AppDecorations.ctaGlow(),
                      ),
                      child: loading
                          ? Padding(
                              padding: const EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              size: 21,
                              color: AppColors.onPrimary,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loading
                                ? 'Finding your location…'
                                : 'Use my current location',
                            style: AppTypography.bodyTextBold.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Fill your address in one tap',
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
          if (filled)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.warningDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Location can be off by a few buildings. Add your flat '
                      'or house number and check the street before saving.',
                      style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                        color: AppColors.warningDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
