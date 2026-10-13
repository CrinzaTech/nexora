import 'dart:async';
import 'dart:ui' show Locale;

import 'package:dartz/dartz.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Why "Use my current location" couldn't fill the form.
enum StoreLocateError {
  /// Location services (GPS) are switched off on the device.
  serviceOff,

  /// The learner said no this time; asking again is fine.
  denied,

  /// Blocked for good — only the system settings can undo it.
  deniedForever,

  /// The device is outside India, where the store doesn't deliver.
  outsideIndia,

  /// No fix, or the geocoder had no address for it.
  notFound,
}

/// The parts of a delivery address a location can answer. Any of them may
/// be null — a rural fix often has no street, and GPS never knows the flat.
class StoreLocatedAddress {
  final String? line1;
  final String? area;
  final String? city;

  /// As the platform names it ("Maharashtra"); the form maps it to a
  /// GST state code from A1.
  final String? stateName;
  final String? pincode;

  const StoreLocatedAddress({
    this.line1,
    this.area,
    this.city,
    this.stateName,
    this.pincode,
  });
}

/// Turns the device's position into an address using the operating
/// system's own reverse geocoder (Android `Geocoder`, iOS `CLGeocoder`):
/// free, no API key, and the coordinates never leave the phone through
/// us — only the address the learner then chooses to save.
///
/// Permission is asked for here, on the tap, never on screen open.
class StoreLocationService {
  /// English names regardless of the device language, so the state can be
  /// matched against A1's list.
  static const _locale = Locale('en', 'IN');

  Future<Either<StoreLocateError, StoreLocatedAddress>> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const Left(StoreLocateError.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const Left(StoreLocateError.deniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return const Left(StoreLocateError.denied);
    }

    final position = await _position();
    if (position == null) return const Left(StoreLocateError.notFound);

    final List<Placemark> marks;
    try {
      marks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        locale: _locale,
      );
    } catch (_) {
      // No network for the geocoder, or no geocoder on this device.
      return const Left(StoreLocateError.notFound);
    }
    if (marks.isEmpty) return const Left(StoreLocateError.notFound);

    // Prefer a result that carries a pincode — the most useful field.
    final mark = marks.firstWhere(
      (m) => (m.postalCode ?? '').trim().isNotEmpty,
      orElse: () => marks.first,
    );
    final country = mark.isoCountryCode?.toUpperCase();
    if (country != null && country.isNotEmpty && country != 'IN') {
      return const Left(StoreLocateError.outsideIndia);
    }
    return Right(_toAddress(mark));
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// A fresh fix, falling back to the last known one indoors or on a slow
  /// GPS — a few hundred metres off still gets city, state and pincode.
  Future<Position?> _position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static StoreLocatedAddress _toAddress(Placemark m) {
    String? clean(String? v) {
      final s = v?.trim();
      if (s == null || s.isEmpty) return null;
      // Google "plus codes" (7JWM+2Q Pune) are not something to print on
      // a parcel.
      if (RegExp(
        r'^[2-9CFGHJMPQRVWX]{4,8}\+[2-9CFGHJMPQRVWX]{0,3}\b',
      ).hasMatch(s.toUpperCase())) {
        return null;
      }
      return s;
    }

    final city = clean(m.locality) ?? clean(m.subAdministrativeArea);
    final area = clean(m.subLocality);
    final state = clean(m.administrativeArea);
    final postal = m.postalCode?.replaceAll(RegExp(r'\s'), '');
    final pincode = postal != null && RegExp(r'^[1-9]\d{5}$').hasMatch(postal)
        ? postal
        : null;

    // Street line from whatever the platform split it into: `name` is often
    // a building or house number, `street` sometimes repeats the
    // thoroughfare. Keep each distinct piece once, and nothing that is just
    // the area, city, state or pincode again.
    final taken = {
      for (final v in [area, city, state, pincode, clean(m.country)])
        if (v != null) v.toLowerCase(),
    };
    final pieces = <String>[];
    for (final raw in [m.name, m.subThoroughfare, m.thoroughfare, m.street]) {
      final v = clean(raw);
      if (v == null || taken.contains(v.toLowerCase())) continue;
      final lower = v.toLowerCase();
      // Already said by a longer piece ("MG Road" inside "12, MG Road")…
      if (pieces.any((p) => p.toLowerCase().contains(lower))) continue;
      // …or a longer piece that says this one and more.
      pieces.removeWhere((p) => lower.contains(p.toLowerCase()));
      pieces.add(v);
    }
    final line1 = pieces.join(', ');

    return StoreLocatedAddress(
      // The API wants at least 5 characters; a lone house number is not an
      // address line, so leave the field to the learner instead.
      line1: line1.length >= 5 ? line1 : null,
      area: area,
      city: city,
      stateName: state,
      pincode: pincode,
    );
  }
}
