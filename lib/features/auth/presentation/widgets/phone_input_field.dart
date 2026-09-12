import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/features/auth/data/services/location_country_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Country {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });
}

/// National (post-dial-code) phone number length by country, used to
/// keep the validator honest once countries other than India are
/// selectable. Not a full E.164 validator (no external phone-number
/// package is in this project) — just a min/max digit-count check per
/// country so, e.g., a UAE number isn't forced into a 10-digit shape.
/// Countries not listed fall back to [_defaultPhoneLengthRange].
const Map<String, (int min, int max)> _phoneLengthByCountry = {
  'IN': (10, 10),
  'US': (10, 10),
  'CA': (10, 10),
  'GB': (10, 10),
  'AU': (9, 9),
  'DE': (10, 11),
  'FR': (9, 9),
  'AE': (9, 9),
  'SG': (8, 8),
  'JP': (10, 10),
  'CN': (11, 11),
  'KR': (9, 10),
  'NG': (10, 10),
  'GH': (9, 9),
  'KE': (9, 9),
  'ZA': (9, 9),
  'EG': (10, 10),
  'TZ': (9, 9),
  'UG': (9, 9),
  'BR': (10, 11),
  'MX': (10, 10),
  'AR': (10, 10),
  'CO': (10, 10),
  'PE': (9, 9),
  'PK': (10, 10),
  'BD': (10, 10),
  'ID': (9, 12),
  'PH': (10, 10),
  'VN': (9, 10),
  'TH': (9, 9),
  'MY': (9, 10),
  'SA': (9, 9),
  'QA': (8, 8),
  'KW': (8, 8),
  'TR': (10, 10),
  'IT': (9, 10),
  'ES': (9, 9),
  'NL': (9, 9),
  'BE': (8, 9),
  'CH': (9, 9),
  'SE': (7, 9),
  'NO': (8, 8),
  'IE': (9, 9),
  'PT': (9, 9),
  'PL': (9, 9),
  'RU': (10, 10),
  'UA': (9, 9),
  'NZ': (8, 9),
  'NP': (10, 10),
  'LK': (9, 9),
};
const (int, int) _defaultPhoneLengthRange = (7, 12);

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String)? onChanged;

  /// Country the field starts on. Defaults to India when omitted so
  /// existing call sites that don't care about country selection keep
  /// their current behaviour.
  final Country? initialCountry;

  /// Fires whenever the user picks a different country from the
  /// bottom sheet, so a parent that needs the dial code (e.g. to send
  /// alongside the phone number) can stay in sync instead of reading
  /// stale state.
  final ValueChanged<Country>? onCountryChanged;

  static const List<Country> countries = [
    Country(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
    Country(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
    Country(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    Country(name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
    Country(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
    Country(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
    Country(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
    Country(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
    Country(name: 'UAE', code: 'AE', dialCode: '+971', flag: '🇦🇪'),
    Country(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
    Country(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
    Country(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
    Country(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
    Country(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
    Country(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
    Country(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
    Country(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
    Country(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿'),
    Country(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬'),
    Country(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
    Country(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
    Country(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
    Country(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
    Country(name: 'Peru', code: 'PE', dialCode: '+51', flag: '🇵🇪'),
    Country(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
    Country(name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
    Country(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
    Country(name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
    Country(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),
    Country(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
    Country(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
    Country(name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
    Country(name: 'Qatar', code: 'QA', dialCode: '+974', flag: '🇶🇦'),
    Country(name: 'Kuwait', code: 'KW', dialCode: '+965', flag: '🇰🇼'),
    Country(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
    Country(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
    Country(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
    Country(name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
    Country(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
    Country(name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
    Country(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
    Country(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
    Country(name: 'Ireland', code: 'IE', dialCode: '+353', flag: '🇮🇪'),
    Country(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
    Country(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
    Country(name: 'Russia', code: 'RU', dialCode: '+7', flag: '🇷🇺'),
    Country(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),
    Country(name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
    Country(name: 'Nepal', code: 'NP', dialCode: '+977', flag: '🇳🇵'),
    Country(name: 'Sri Lanka', code: 'LK', dialCode: '+94', flag: '🇱🇰'),
  ];

  const PhoneInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.initialCountry,
    this.onCountryChanged,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late Country selectedCountry =
      widget.initialCountry ?? PhoneInputField.countries.first;

  (int, int) get _lengthRange =>
      _phoneLengthByCountry[selectedCountry.code] ?? _defaultPhoneLengthRange;

  bool _isResolvingCountry = false;

  /// Tapping the flag resolves the dialling code from the caller's IP
  /// rather than opening a list to choose from — the country is a fact
  /// about where you are, not a preference.
  ///
  /// Every failure path is silent and leaves the current selection
  /// alone: no network, a lookup the server couldn't resolve, or a
  /// private/loopback caller all keep whatever was already set (India
  /// by default). That means a flaky network can never strand someone
  /// on the wrong code — it just doesn't change.
  Future<void> _resolveCountryFromLocation() async {
    if (_isResolvingCountry) return;
    setState(() => _isResolvingCountry = true);

    final resolved = await sl<LocationCountryService>().resolveCountry();

    if (!mounted) return;
    setState(() {
      _isResolvingCountry = false;
      if (resolved != null) selectedCountry = resolved;
    });
    if (resolved != null) widget.onCountryChanged?.call(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final (min, max) = _lengthRange;
    return CustomTextFormField(
      maxLine: 1,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      hintText: '9000000000',
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      onChanged: widget.onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(max),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < min || digits.length > max) {
          return min == max
              ? 'Please enter a valid $min-digit phone number'
              : 'Please enter a valid phone number';
        }
        return null;
      },
      prefixIcon: Container(
        width: Screen.getHorizontalSizeCapped(90),
        margin: Screen.getMargin(left: 5),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isResolvingCountry ? null : _resolveCountryFromLocation,
            splashColor: AppColors.primary.withValues(alpha: 0.09),
            highlightColor: AppColors.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
            child: Padding(
              padding: Screen.getPadding(horizontal: AppSizes.paddingXS),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isResolvingCountry)
                      SizedBox(
                        width: Screen.getSize(16),
                        height: Screen.getSize(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(
                        selectedCountry.flag,
                        style: TextStyle(
                          fontSize: Screen.getFontSizeCapped(18),
                        ),
                      ),
                    SizedBox(width: Screen.getHorizontalSize(4)),
                    Text(
                      selectedCountry.dialCode,
                      style: TextStyle(
                        fontSize: Screen.getFontSizeCapped(12),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: Screen.getHorizontalSize(20),
                      color: AppColors.textPrimary,
                    ),
                    Container(
                      width: 1,
                      height: Screen.getVerticalSize(20),
                      color: AppColors.grey300,
                      margin: Screen.getMargin(left: AppSizes.paddingS),
                    ),
                  ],
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
// Country Picker Bottom Sheet — separate StatefulWidget so the
// search box can actually filter the list (previously a TODO no-op
// with a static list containing only India).
// ─────────────────────────────────────────────────────────────
class _CountryPickerSheet extends StatefulWidget {
  final List<Country> countries;
  final Country selected;

  const _CountryPickerSheet({required this.countries, required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<Country> _filtered = widget.countries;

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(q) ||
                      c.dialCode.contains(q) ||
                      c.code.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: AppTypography.h5SemiBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No countries found',
                      style: AppTypography.bodyTextLargeMedium.copyWith(
                        color: AppColors.grey500,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final country = _filtered[index];
                      final isSelected = country.code == widget.selected.code;
                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.name,
                          style: AppTypography.bodyTextLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: Text(
                          country.dialCode,
                          style: AppTypography.bodyTextLargeMedium.copyWith(
                            color: AppColors.grey500,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, country),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
