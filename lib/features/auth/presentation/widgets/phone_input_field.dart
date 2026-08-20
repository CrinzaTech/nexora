import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
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

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String)? onChanged;

  const PhoneInputField({super.key, required this.controller, this.onChanged});

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  static const List<Country> countries = [
    Country(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
    // Country(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    // Country(name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
    // Country(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
    // Country(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
    // Country(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
    // Country(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
    // Country(name: 'UAE', code: 'AE', dialCode: '+971', flag: '🇦🇪'),
    // Country(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
    // Country(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
    // Country(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
    // Country(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
  ];

  Country selectedCountry = countries.first;

  void _showCountryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                onChanged: (value) {
                  // Todo: Implement search
                },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final isSelected = country.code == selectedCountry.code;
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
                    onTap: () {
                      setState(() => selectedCountry = country);
                      Navigator.pop(context);
                    },
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      maxLine: 1,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      hintText: '9000000000',
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      onChanged: widget.onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10 || digits.length > 10) {
          return 'Please enter a valid phone number';
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
            onTap: _showCountryBottomSheet,
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
                    Text(
                      selectedCountry.flag,
                      style: TextStyle(fontSize: Screen.getFontSizeCapped(18)),
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
