import 'store_common_model.dart';

/// A1 — a state or UT with its 2-digit GST code. The code decides which
/// GST applies, which is why the form offers a list, never a text box.
class StoreGstState {
  final String code;
  final String name;
  final bool isUnionTerritory;

  const StoreGstState({
    required this.code,
    required this.name,
    required this.isUnionTerritory,
  });

  factory StoreGstState.fromJson(Map<String, dynamic> json) => StoreGstState(
    code: readString(json['code']),
    name: readString(json['name']),
    isUnionTerritory: readBool(json['isUnionTerritory']),
  );
}

/// `addressType` on the wire: 1 home · 2 work / hostel · 3 other.
enum StoreAddressType {
  home(1, 'Home'),
  work(2, 'Work / Hostel'),
  other(3, 'Other');

  final int wire;
  final String label;
  const StoreAddressType(this.wire, this.label);

  static StoreAddressType fromWire(int v) => values.firstWhere(
    (t) => t.wire == v,
    orElse: () => StoreAddressType.other,
  );
}

class StoreAddress {
  final int id;
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String stateCode;
  final String? stateName;
  final String pincode;
  final StoreAddressType type;
  final bool isDefault;

  const StoreAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.stateCode,
    this.stateName,
    required this.pincode,
    required this.type,
    required this.isDefault,
  });

  /// "Flat 12, Shanti Apartments, MG Road, Near City Mall, Opp. SBI"
  String get streetLine => [
    line1,
    if (line2 != null) line2!,
    if (landmark != null) landmark!,
  ].join(', ');

  /// "Pune, Maharashtra 411001"
  String get cityLine =>
      '$city${stateName != null ? ', $stateName' : ''} $pincode';

  factory StoreAddress.fromJson(Map<String, dynamic> json) => StoreAddress(
    id: readInt(json['id']),
    fullName: readString(json['fullName']),
    phone: readString(json['phone']),
    line1: readString(json['line1']),
    line2: readStringOrNull(json['line2']),
    landmark: readStringOrNull(json['landmark']),
    city: readString(json['city']),
    stateCode: readString(json['stateCode']),
    stateName: readStringOrNull(json['stateName']),
    pincode: readString(json['pincode']),
    type: StoreAddressType.fromWire(readInt(json['addressType'], 1)),
    isDefault: readBool(json['isDefault']),
  );
}

/// A3 / A4 body.
class StoreAddressInput {
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String stateCode;
  final String pincode;
  final StoreAddressType type;
  final bool isDefault;

  const StoreAddressInput({
    required this.fullName,
    required this.phone,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.stateCode,
    required this.pincode,
    required this.type,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() {
    String? blankToNull(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'line1': line1.trim(),
      'line2': blankToNull(line2),
      'landmark': blankToNull(landmark),
      'city': city.trim(),
      'stateCode': stateCode,
      'pincode': pincode.trim(),
      'addressType': type.wire,
      'isDefault': isDefault,
    };
  }
}
