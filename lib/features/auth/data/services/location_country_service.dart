import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/features/auth/presentation/widgets/phone_input_field.dart'
    show Country;
import 'package:flutter/foundation.dart';

/// Resolves the caller's dialling code from their IP via
/// `GET /api/v1/location/me`, so the phone field can carry the right
/// country without the user hunting through a list.
///
/// The endpoint always answers 200 with a usable body — a failed lookup
/// or a private/loopback caller comes back as `isResolved: false`
/// carrying the configured default. This service treats that, a network
/// failure, and a malformed payload identically: it returns null and the
/// caller keeps whatever country it already had.
class LocationCountryService {
  final ApiClient _apiClient;

  LocationCountryService(this._apiClient);

  Future<Country?> resolveCountry() async {
    try {
      final response = await _apiClient.getLocation();
      final data = response['data'];
      if (data is! Map) return null;

      // Anything short of a real resolution leaves the field alone.
      if (data['isResolved'] != true) return null;

      final countryCode = (data['countryCode'] as String?)?.toUpperCase();
      final stdCode = data['stdCode'] as String?;
      if (countryCode == null || stdCode == null || stdCode.isEmpty) {
        return null;
      }

      // Built straight from the payload rather than matched against the
      // field's hardcoded list, so countries outside that list work too.
      // The field looks its length rules up by `code`, so those still
      // apply wherever it has them.
      return Country(
        name: (data['country'] as String?) ?? countryCode,
        code: countryCode,
        dialCode: stdCode,
        flag: _flagFor(countryCode),
      );
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      return null;
    }
  }

  /// Builds the flag emoji from an ISO 3166-1 alpha-2 code by mapping
  /// each letter to its regional-indicator symbol (US → 🇺🇸).
  static String _flagFor(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    const base = 0x1F1E6; // regional indicator 'A'
    final codeUnits = countryCode.codeUnits
        .map((c) => base + (c - 0x41))
        .toList();
    return String.fromCharCodes(codeUnits);
  }
}
