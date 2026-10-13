import 'store_common_model.dart';

/// Switch on [key], never on [label].
class StoreOrderStatus {
  final int code;

  /// `placed` · `confirmed` · `shipped` · `delivered` · `cancelled`, or a
  /// value added later (shown by its label).
  final String key;
  final String label;

  const StoreOrderStatus({
    required this.code,
    required this.key,
    required this.label,
  });

  bool get isPlaced => key == 'placed';
  bool get isConfirmed => key == 'confirmed';
  bool get isShipped => key == 'shipped';
  bool get isDelivered => key == 'delivered';
  bool get isCancelled => key == 'cancelled';

  factory StoreOrderStatus.fromJson(Map<String, dynamic> json) =>
      StoreOrderStatus(
        code: readInt(json['code']),
        key: readString(json['key']).toLowerCase(),
        label: readString(json['label'], 'Processing'),
      );
}

/// `refund` on an order: none · initiated · processed · failed.
enum StoreRefundState {
  none(''),
  initiated('Refund started'),
  processed('Refunded'),
  failed('Refund delayed, we are on it');

  final String label;
  const StoreRefundState(this.label);

  static StoreRefundState fromWire(String? v) => values.firstWhere(
    (r) => r.name == v?.toLowerCase(),
    orElse: () => StoreRefundState.none,
  );
}

/// O1 group filter.
enum StoreOrderGroup {
  all('All'),
  active('Active'),
  delivered('Delivered'),
  cancelled('Cancelled');

  final String label;
  const StoreOrderGroup(this.label);
}

/// O1 row.
class StoreOrderSummary {
  final String orderNo;
  final StoreOrderStatus status;
  final DateTime? placedAt;
  final int itemCount;
  final int totalQty;
  final String firstItemTitle;
  final String? firstItemImage;
  final double payable;
  final DateTime? expectedDeliveryFrom;
  final DateTime? expectedDeliveryTo;
  final DateTime? deliveredAt;
  final StoreRefundState refund;

  const StoreOrderSummary({
    required this.orderNo,
    required this.status,
    this.placedAt,
    required this.itemCount,
    required this.totalQty,
    required this.firstItemTitle,
    this.firstItemImage,
    required this.payable,
    this.expectedDeliveryFrom,
    this.expectedDeliveryTo,
    this.deliveredAt,
    required this.refund,
  });

  factory StoreOrderSummary.fromJson(Map<String, dynamic> json) =>
      StoreOrderSummary(
        orderNo: readString(json['orderNo']),
        status: StoreOrderStatus.fromJson(readMap(json['status'])),
        placedAt: readDate(json['placedAt']),
        itemCount: readInt(json['itemCount'], 1),
        totalQty: readInt(json['totalQty'], 1),
        firstItemTitle: readString(json['firstItemTitle']),
        firstItemImage: readStringOrNull(json['firstItemImage']),
        payable: readDouble(json['payable']),
        expectedDeliveryFrom: readDate(json['expectedDeliveryFrom']),
        expectedDeliveryTo: readDate(json['expectedDeliveryTo']),
        deliveredAt: readDate(json['deliveredAt']),
        refund: StoreRefundState.fromWire(readStringOrNull(json['refund'])),
      );
}

class StoreMyReview {
  final int rating;
  final String? comment;

  const StoreMyReview({required this.rating, this.comment});

  static StoreMyReview? fromJson(dynamic json) {
    final m = readMapOrNull(json);
    if (m == null) return null;
    return StoreMyReview(
      rating: readInt(m['rating']),
      comment: readStringOrNull(m['comment']),
    );
  }
}

class StoreOrderItem {
  final int itemId;
  final String productId;
  final String title;
  final String? imageUrl;
  final int qty;
  final double unitMrp;
  final double unitPrice;
  final double lineTotal;
  final StoreCover? warranty;
  final StoreCover? guarantee;
  final bool canReview;
  final StoreMyReview? myReview;

  const StoreOrderItem({
    required this.itemId,
    required this.productId,
    required this.title,
    this.imageUrl,
    required this.qty,
    required this.unitMrp,
    required this.unitPrice,
    required this.lineTotal,
    this.warranty,
    this.guarantee,
    required this.canReview,
    this.myReview,
  });

  factory StoreOrderItem.fromJson(Map<String, dynamic> json) => StoreOrderItem(
    itemId: readInt(json['itemId']),
    productId: readString(json['productId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    qty: readInt(json['qty'], 1),
    unitMrp: readDouble(json['unitMrp']),
    unitPrice: readDouble(json['unitPrice']),
    lineTotal: readDouble(json['lineTotal']),
    warranty: StoreCover.fromJson(json['warranty']),
    guarantee: StoreCover.fromJson(json['guarantee']),
    canReview: readBool(json['canReview']),
    myReview: StoreMyReview.fromJson(json['myReview']),
  );
}

class StoreShipTo {
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String? stateName;
  final String pincode;

  const StoreShipTo({
    required this.fullName,
    required this.phone,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    this.stateName,
    required this.pincode,
  });

  String get streetLine => [
    line1,
    if (line2 != null) line2!,
    if (landmark != null) landmark!,
  ].join(', ');

  String get cityLine =>
      '$city${stateName != null ? ', $stateName' : ''} $pincode';

  factory StoreShipTo.fromJson(Map<String, dynamic> json) => StoreShipTo(
    fullName: readString(json['fullName']),
    phone: readString(json['phone']),
    line1: readString(json['line1']),
    line2: readStringOrNull(json['line2']),
    landmark: readStringOrNull(json['landmark']),
    city: readString(json['city']),
    stateName: readStringOrNull(json['stateName']),
    pincode: readString(json['pincode']),
  );
}

class StoreTracking {
  final String? courier;
  final String? trackingNumber;
  final String? trackingUrl;

  /// Shown under the button ("opens www.delhivery.com").
  final String? trackingHost;

  const StoreTracking({
    this.courier,
    this.trackingNumber,
    this.trackingUrl,
    this.trackingHost,
  });

  bool get isEmpty => trackingNumber == null && trackingUrl == null;

  static StoreTracking? fromJson(dynamic json) {
    final m = readMapOrNull(json);
    if (m == null) return null;
    final t = StoreTracking(
      courier: readStringOrNull(m['courier']),
      trackingNumber: readStringOrNull(m['trackingNumber']),
      trackingUrl: readStringOrNull(m['trackingUrl']),
      trackingHost: readStringOrNull(m['trackingHost']),
    );
    return t.isEmpty ? null : t;
  }
}

class StoreOrderPayment {
  final double itemsTotal;
  final double deliveryCharge;
  final double couponDiscount;
  final StoreTax tax;
  final double gatewayFee;
  final double paid;

  /// `tax_invoice` when the seller is GST-registered, `bill_of_supply`
  /// when not.
  final String documentType;
  final String? sellerGstin;

  const StoreOrderPayment({
    required this.itemsTotal,
    required this.deliveryCharge,
    required this.couponDiscount,
    required this.tax,
    required this.gatewayFee,
    required this.paid,
    required this.documentType,
    this.sellerGstin,
  });

  bool get isTaxInvoice => documentType == 'tax_invoice';

  factory StoreOrderPayment.fromJson(Map<String, dynamic> json) =>
      StoreOrderPayment(
        itemsTotal: readDouble(json['itemsTotal']),
        deliveryCharge: readDouble(json['deliveryCharge']),
        couponDiscount: readDouble(json['couponDiscount']),
        tax: StoreTax.fromJson(readMap(json['tax'])),
        gatewayFee: readDouble(json['gatewayFee']),
        paid: readDouble(json['paid']),
        documentType: readString(json['documentType'], 'bill_of_supply'),
        sellerGstin: readStringOrNull(json['sellerGstin']),
      );
}

class StoreTimelineEvent {
  final String label;
  final String? note;
  final DateTime? at;

  const StoreTimelineEvent({required this.label, this.note, this.at});

  factory StoreTimelineEvent.fromJson(Map<String, dynamic> json) =>
      StoreTimelineEvent(
        label: readString(json['label']),
        note: readStringOrNull(json['note']),
        at: readDate(json['at']),
      );
}

/// A refund on a cancelled order. The API leaves the shape open, so only
/// the parts worth showing are read.
class StoreRefund {
  final double amount;
  final String status;
  final DateTime? at;

  const StoreRefund({required this.amount, required this.status, this.at});

  factory StoreRefund.fromJson(Map<String, dynamic> json) => StoreRefund(
    amount: readDouble(json['amount']),
    status: readString(json['status']),
    at: readDate(json['processedAt'] ?? json['createdAt'] ?? json['at']),
  );
}

/// O2.
class StoreOrderDetail {
  final String orderNo;
  final StoreOrderStatus status;
  final String? sellerName;
  final DateTime? placedAt;
  final DateTime? expectedDeliveryFrom;
  final DateTime? expectedDeliveryTo;
  final DateTime? deliveredAt;
  final List<StoreOrderItem> items;
  final StoreShipTo? shipTo;
  final StoreTracking? tracking;
  final StoreOrderPayment? payment;
  final List<StoreRefund> refunds;
  final String? cancelReason;
  final String? cancelledBy;
  final List<StoreTimelineEvent> timeline;
  final bool canCancel;
  final bool canConfirmReceived;

  const StoreOrderDetail({
    required this.orderNo,
    required this.status,
    this.sellerName,
    this.placedAt,
    this.expectedDeliveryFrom,
    this.expectedDeliveryTo,
    this.deliveredAt,
    required this.items,
    this.shipTo,
    this.tracking,
    this.payment,
    required this.refunds,
    this.cancelReason,
    this.cancelledBy,
    required this.timeline,
    required this.canCancel,
    required this.canConfirmReceived,
  });

  factory StoreOrderDetail.fromJson(Map<String, dynamic> json) {
    final shipTo = readMapOrNull(json['shipTo']);
    final payment = readMapOrNull(json['payment']);
    return StoreOrderDetail(
      orderNo: readString(json['orderNo']),
      status: StoreOrderStatus.fromJson(readMap(json['status'])),
      sellerName: readStringOrNull(json['sellerName']),
      placedAt: readDate(json['placedAt']),
      expectedDeliveryFrom: readDate(json['expectedDeliveryFrom']),
      expectedDeliveryTo: readDate(json['expectedDeliveryTo']),
      deliveredAt: readDate(json['deliveredAt']),
      items: readList(json['items'], StoreOrderItem.fromJson),
      shipTo: shipTo == null ? null : StoreShipTo.fromJson(shipTo),
      tracking: StoreTracking.fromJson(json['tracking']),
      payment: payment == null ? null : StoreOrderPayment.fromJson(payment),
      refunds: readList(json['refunds'], StoreRefund.fromJson),
      cancelReason: readStringOrNull(json['cancelReason']),
      cancelledBy: readStringOrNull(json['cancelledBy']),
      timeline: readList(json['timeline'], StoreTimelineEvent.fromJson),
      canCancel: readBool(json['canCancel']),
      canConfirmReceived: readBool(json['canConfirmReceived']),
    );
  }
}
