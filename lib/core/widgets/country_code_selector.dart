import 'package:flutter/material.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/screen.dart';

/// Country code data model
class CountryCode {
  const CountryCode({
    required this.code,
    required this.dialCode,
    required this.name,
    required this.flag,
  });

  final String code; // e.g., 'US', 'IN', 'GB'
  final String dialCode; // e.g., '+1', '+91', '+44'
  final String name; // e.g., 'United States', 'India', 'United Kingdom'
  final String flag; // Emoji flag

  @override
  String toString() => '$flag $dialCode';
}

/// Common country codes
class CountryCodes {
  CountryCodes._();

  static const List<CountryCode> all = [
    CountryCode(code: 'US', dialCode: '+1', name: 'United States', flag: '🇺🇸'),
    CountryCode(code: 'GB', dialCode: '+44', name: 'United Kingdom', flag: '🇬🇧'),
    CountryCode(code: 'IN', dialCode: '+91', name: 'India', flag: '🇮🇳'),
    CountryCode(code: 'CA', dialCode: '+1', name: 'Canada', flag: '🇨🇦'),
    CountryCode(code: 'AU', dialCode: '+61', name: 'Australia', flag: '🇦🇺'),
    CountryCode(code: 'DE', dialCode: '+49', name: 'Germany', flag: '🇩🇪'),
    CountryCode(code: 'FR', dialCode: '+33', name: 'France', flag: '🇫🇷'),
    CountryCode(code: 'AE', dialCode: '+971', name: 'United Arab Emirates', flag: '🇦🇪'),
    CountryCode(code: 'SA', dialCode: '+966', name: 'Saudi Arabia', flag: '🇸🇦'),
    CountryCode(code: 'PK', dialCode: '+92', name: 'Pakistan', flag: '🇵🇰'),
    CountryCode(code: 'BD', dialCode: '+880', name: 'Bangladesh', flag: '🇧🇩'),
    CountryCode(code: 'SG', dialCode: '+65', name: 'Singapore', flag: '🇸🇬'),
    CountryCode(code: 'MY', dialCode: '+60', name: 'Malaysia', flag: '🇲🇾'),
    CountryCode(code: 'ID', dialCode: '+62', name: 'Indonesia', flag: '🇮🇩'),
    CountryCode(code: 'TH', dialCode: '+66', name: 'Thailand', flag: '🇹🇭'),
    CountryCode(code: 'PH', dialCode: '+63', name: 'Philippines', flag: '🇵🇭'),
    CountryCode(code: 'JP', dialCode: '+81', name: 'Japan', flag: '🇯🇵'),
    CountryCode(code: 'KR', dialCode: '+82', name: 'South Korea', flag: '🇰🇷'),
    CountryCode(code: 'CN', dialCode: '+86', name: 'China', flag: '🇨🇳'),
    CountryCode(code: 'NL', dialCode: '+31', name: 'Netherlands', flag: '🇳🇱'),
    CountryCode(code: 'IT', dialCode: '+39', name: 'Italy', flag: '🇮🇹'),
    CountryCode(code: 'ES', dialCode: '+34', name: 'Spain', flag: '🇪🇸'),
    CountryCode(code: 'BR', dialCode: '+55', name: 'Brazil', flag: '🇧🇷'),
    CountryCode(code: 'MX', dialCode: '+52', name: 'Mexico', flag: '🇲🇽'),
    CountryCode(code: 'ZA', dialCode: '+27', name: 'South Africa', flag: '🇿🇦'),
    CountryCode(code: 'NG', dialCode: '+234', name: 'Nigeria', flag: '🇳🇬'),
    CountryCode(code: 'EG', dialCode: '+20', name: 'Egypt', flag: '🇪🇬'),
  ];
}

/// Country code selector button widget
class CountryCodeSelector extends StatelessWidget {
  const CountryCodeSelector({
    super.key,
    required this.selectedCountry,
    required this.onCountrySelected,
    this.enabled = true,
    this.compact = false,
  });

  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountrySelected;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return InkWell(
      onTap: enabled
          ? () => _showCountryCodeBottomSheet(context, onCountrySelected)
          : null,
      borderRadius: AppSizes.borderRadiusM,
      child: Container(
        padding: Screen.getPadding(
          horizontal: compact ? AppSizes.paddingM : AppSizes.paddingM,
          vertical: AppSizes.paddingM,
        ),
        decoration: compact
            ? null
            : BoxDecoration(
                border: Border.all(
                  color: enabled ? AppColors.grey200 : AppColors.grey100,
                ),
                borderRadius: AppSizes.borderRadiusM,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCountry.flag,
              style: const TextStyle(fontSize: 24),
            ),
            SizedBox(width: Screen.getPadding(horizontal: AppSizes.paddingS).left),
            Text(
              selectedCountry.dialCode,
              // style: AppTypography.bodyMedium.copyWith(
              //   color: AppColors.grey700,
              //   fontWeight: FontWeight.w500,
              // ),
            ),
            if (!compact) ...[
              SizedBox(width: Screen.getPadding(horizontal: AppSizes.paddingS).left),
              Icon(
                Icons.keyboard_arrow_down,
                size: AppSizes.iconS,
                color: enabled ? AppColors.grey600 : AppColors.grey300,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCountryCodeBottomSheet(
    BuildContext context,
    ValueChanged<CountryCode> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CountryCodeBottomSheet(
        countries: CountryCodes.all,
        onSelected: (country) {
          Navigator.pop(context);
          onSelected(country);
        },
      ),
    );
  }
}

/// Country code selection bottom sheet
class _CountryCodeBottomSheet extends StatefulWidget {
  const _CountryCodeBottomSheet({
    required this.countries,
    required this.onSelected,
  });

  final List<CountryCode> countries;
  final ValueChanged<CountryCode> onSelected;

  @override
  State<_CountryCodeBottomSheet> createState() =>
      _CountryCodeBottomSheetState();
}

class _CountryCodeBottomSheetState extends State<_CountryCodeBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countries;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredCountries = widget.countries;
      } else {
        final query = _searchController.text.toLowerCase();
        _filteredCountries = widget.countries.where((country) {
          return country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query) ||
              country.dialCode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: Screen.getPadding(
              vertical: AppSizes.paddingM,
            ).copyWith(left: 0, right: 0),
            width: Screen.getSize(40),
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: Screen.getPadding(horizontal: AppSizes.paddingL).copyWith(
                  bottom: Screen.getPadding(vertical: AppSizes.paddingM).top,
                ),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  // style: AppTypography.h6.copyWith(
                  //   color: AppColors.grey900,
                  //   fontWeight: FontWeight.w600,
                  // ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: Screen.getPadding(horizontal: AppSizes.paddingL).copyWith(
                  bottom: Screen.getPadding(vertical: AppSizes.paddingM).top,
                ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: AppSizes.borderRadiusM,
                ),
                contentPadding: Screen.getPadding(all: AppSizes.paddingM),
              ),
            ),
          ),

          // Country list
          Expanded(
            child: ListView.builder(
              padding: Screen.getPadding(horizontal: AppSizes.paddingL).copyWith(
                    bottom: Screen.getPadding(vertical: AppSizes.paddingL).top,
                  ),
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                return InkWell(
                  onTap: () => widget.onSelected(country),
                  child: Container(
                    padding: Screen.getPadding(vertical: AppSizes.paddingM),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.grey100,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          country.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                        SizedBox(width: Screen.getPadding(horizontal: AppSizes.paddingM).left),
                        Expanded(
                          child: Text(
                            country.name,
                            // style: AppTypography.bodyMedium.copyWith(
                            //   color: AppColors.grey900,
                            // ),
                          ),
                        ),
                        Text(
                          country.dialCode,
                          // style: AppTypography.bodyMedium.copyWith(
                          //   color: AppColors.grey500,
                          // ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
