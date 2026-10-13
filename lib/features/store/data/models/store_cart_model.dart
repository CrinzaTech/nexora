import 'store_common_model.dart';

class StoreCartLine {
  final String productId;
  final String title;
  final String? imageUrl;
  final int qty;

  /// What the stepper may go up to right now (stock and per-order limit).
  final int maxQty;
  final double unitMrp;
  final double unitPrice;
  final double lineTotal;
  final bool isAvailable;
  final StoreLineIssue? issue;

  const StoreCartLine({
    required this.productId,
    required this.title,
    this.imageUrl,
    required this.qty,
    required this.maxQty,
    required this.unitMrp,
    required this.unitPrice,
    required this.lineTotal,
    required this.isAvailable,
    this.issue,
  });

  factory StoreCartLine.fromJson(Map<String, dynamic> json) => StoreCartLine(
    productId: readString(json['productId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    qty: readInt(json['qty'], 1),
    maxQty: readInt(json['maxQty']),
    unitMrp: readDouble(json['unitMrp']),
    unitPrice: readDouble(json['unitPrice']),
    lineTotal: readDouble(json['lineTotal']),
    isAvailable: readBool(json['isAvailable'], true),
    issue: StoreLineIssue.fromJson(json['issue']),
  );
}

/// K1 (also returned by K2) — prices and stock are live.
class StoreCart {
  final List<StoreCartLine> items;
  final int itemCount;
  final double itemsTotal;
  final double mrpTotal;
  final double savings;

  /// Charged once per order: the highest among the products, not the sum.
  final double deliveryCharge;
  final double estimatedTotal;

  /// True only when every line is fine. Nothing is dropped silently.
  final bool canCheckout;

  const StoreCart({
    required this.items,
    required this.itemCount,
    required this.itemsTotal,
    required this.mrpTotal,
    required this.savings,
    required this.deliveryCharge,
    required this.estimatedTotal,
    required this.canCheckout,
  });

  static const empty = StoreCart(
    items: [],
    itemCount: 0,
    itemsTotal: 0,
    mrpTotal: 0,
    savings: 0,
    deliveryCharge: 0,
    estimatedTotal: 0,
    canCheckout: false,
  );

  bool get isEmpty => items.isEmpty;

  /// Quantity of [productId] in the cart, 0 when it isn't there.
  int qtyOf(String productId) {
    for (final line in items) {
      if (line.productId == productId) return line.qty;
    }
    return 0;
  }

  factory StoreCart.fromJson(Map<String, dynamic> json) => StoreCart(
    items: readList(json['items'], StoreCartLine.fromJson),
    itemCount: readInt(json['itemCount']),
    itemsTotal: readDouble(json['itemsTotal']),
    mrpTotal: readDouble(json['mrpTotal']),
    savings: readDouble(json['savings']),
    deliveryCharge: readDouble(json['deliveryCharge']),
    estimatedTotal: readDouble(json['estimatedTotal']),
    canCheckout: readBool(json['canCheckout']),
  );
}
