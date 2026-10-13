/// Shared pieces of the Store API payloads, plus the lenient readers every
/// Store model parses through.
///
/// The readers never throw: a missing or mistyped field falls back to a
/// neutral value, so one odd product can't blank a whole rail. Money is
/// always read as `double` (the API sends `540`, `540.0` and `540.00`
/// interchangeably) and is **never** computed on — see STORE_API.md §1.
library;

double readDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? readDoubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int readInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? readIntOrNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String readString(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

/// Null for a missing or blank string, so callers can `?? 'fallback'`.
String? readStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

bool readBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

/// Instants carry a `Z` and are converted to device time. Calendar dates
/// (`expectedDeliveryFrom` etc.) come without one and are IST dates —
/// parsed as-is, so "15 Oct" stays 15 Oct on any device clock.
DateTime? readDate(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final parsed = DateTime.tryParse(v);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

Map<String, dynamic> readMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

Map<String, dynamic>? readMapOrNull(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<T> readList<T>(dynamic v, T Function(Map<String, dynamic>) parse) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map) parse(Map<String, dynamic>.from(e)),
  ];
}

/// One page of a paged Store list (C3, C5, O1).
class StorePage<T> {
  final List<T> items;
  final int pageNo;
  final int pageSize;
  final int total;
  final bool hasMore;

  const StorePage({
    required this.items,
    required this.pageNo,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  factory StorePage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    return StorePage(
      items: readList(json['items'], parse),
      pageNo: readInt(json['pageNo'], 1),
      pageSize: readInt(json['pageSize'], 20),
      total: readInt(json['total']),
      hasMore: readBool(json['hasMore']),
    );
  }
}

/// A product's warranty (a defect is **repaired**) or guarantee (the item
/// is **replaced or refunded**). Null on the parent when it has none.
class StoreCover {
  final int months;
  final String? providedBy;
  final String? terms;

  /// Set once the order is delivered — "Warranty until 10 Oct 2027".
  final DateTime? validUntil;

  const StoreCover({
    required this.months,
    this.providedBy,
    this.terms,
    this.validUntil,
  });

  static StoreCover? fromJson(dynamic json) {
    final m = readMapOrNull(json);
    if (m == null) return null;
    return StoreCover(
      months: readInt(m['months']),
      providedBy: readStringOrNull(m['providedBy']),
      terms: readStringOrNull(m['terms']),
      validUntil: readDate(m['validUntil']),
    );
  }
}

/// GST lines of a quote or a paid order. Shown, never recomputed.
class StoreTax {
  /// `INTRA` (CGST + SGST) or `INTER` (IGST).
  final String supplyType;
  final bool sellerGstRegistered;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const StoreTax({
    required this.supplyType,
    required this.sellerGstRegistered,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });

  bool get isInter => supplyType.toUpperCase() == 'INTER';

  factory StoreTax.fromJson(Map<String, dynamic> json) => StoreTax(
    supplyType: readString(json['supplyType'], 'INTRA'),
    sellerGstRegistered: readBool(json['sellerGstRegistered']),
    taxable: readDouble(json['taxable']),
    cgst: readDouble(json['cgst']),
    sgst: readDouble(json['sgst']),
    igst: readDouble(json['igst']),
    total: readDouble(json['total']),
  );
}

/// A per-line problem on the cart or a quote. The [message] is written to
/// be shown as-is.
class StoreLineIssue {
  /// `UNAVAILABLE` · `OUT_OF_STOCK` · `LOW_STOCK` · `QTY_LIMIT`.
  final String code;
  final String message;

  const StoreLineIssue({required this.code, required this.message});

  bool get isUnavailable => code == 'UNAVAILABLE';
  bool get isOutOfStock => code == 'OUT_OF_STOCK';

  /// The line can be fixed by lowering its quantity to `maxQty`.
  bool get canReduce => code == 'LOW_STOCK' || code == 'QTY_LIMIT';

  static StoreLineIssue? fromJson(dynamic json) {
    final m = readMapOrNull(json);
    if (m == null) return null;
    return StoreLineIssue(
      code: readString(m['code']),
      message: readString(m['message'], 'This item needs attention.'),
    );
  }
}
