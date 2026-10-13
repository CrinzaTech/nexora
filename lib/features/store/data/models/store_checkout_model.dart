import 'store_address_model.dart';
import 'store_common_model.dart';

/// What is being bought: the whole cart, or one product via Buy Now (which
/// leaves the cart untouched).
class StoreCheckoutSource {
  final String? productId;
  final int qty;

  const StoreCheckoutSource.cart() : productId = null, qty = 0;

  const StoreCheckoutSource.buyNow({
    required String this.productId,
    required this.qty,
  });

  bool get isBuyNow => productId != null;

  /// The P1 body, which P2 extends with `idempotencyKey`.
  Map<String, dynamic> toBody(int addressId) => isBuyNow
      ? {
          'source': 'buy_now',
          'productId': productId,
          'qty': qty,
          'addressId': addressId,
        }
      : {'source': 'cart', 'addressId': addressId};
}

class StoreQuoteLine {
  final String productId;
  final String title;
  final String? imageUrl;
  final int qty;
  final double unitMrp;
  final double unitPrice;
  final double lineTotal;
  final String? hsn;
  final double gstRate;
  final StoreCover? warranty;
  final StoreCover? guarantee;
  final StoreLineIssue? issue;

  const StoreQuoteLine({
    required this.productId,
    required this.title,
    this.imageUrl,
    required this.qty,
    required this.unitMrp,
    required this.unitPrice,
    required this.lineTotal,
    this.hsn,
    required this.gstRate,
    this.warranty,
    this.guarantee,
    this.issue,
  });

  factory StoreQuoteLine.fromJson(Map<String, dynamic> json) => StoreQuoteLine(
    productId: readString(json['productId']),
    title: readString(json['title']),
    imageUrl: readStringOrNull(json['imageUrl']),
    qty: readInt(json['qty'], 1),
    unitMrp: readDouble(json['unitMrp']),
    unitPrice: readDouble(json['unitPrice']),
    lineTotal: readDouble(json['lineTotal']),
    hsn: readStringOrNull(json['hsn']),
    gstRate: readDouble(json['gstRate']),
    warranty: StoreCover.fromJson(json['warranty']),
    guarantee: StoreCover.fromJson(json['guarantee']),
    issue: StoreLineIssue.fromJson(json['issue']),
  );
}

/// P1 — the bill, exactly as it will be charged.
class StoreQuote {
  final List<StoreQuoteLine> items;
  final double itemsTotal;
  final double deliveryCharge;
  final double couponDiscount;
  final double orderValue;
  final StoreTax tax;
  final double gatewayFee;
  final double payable;
  final double savings;
  final DateTime? expectedDeliveryFrom;
  final DateTime? expectedDeliveryTo;
  final StoreAddress? address;
  final bool canPlaceOrder;
  final String? blockedReason;

  const StoreQuote({
    required this.items,
    required this.itemsTotal,
    required this.deliveryCharge,
    required this.couponDiscount,
    required this.orderValue,
    required this.tax,
    required this.gatewayFee,
    required this.payable,
    required this.savings,
    this.expectedDeliveryFrom,
    this.expectedDeliveryTo,
    this.address,
    required this.canPlaceOrder,
    this.blockedReason,
  });

  factory StoreQuote.fromJson(Map<String, dynamic> json) {
    final address = readMapOrNull(json['address']);
    return StoreQuote(
      items: readList(json['items'], StoreQuoteLine.fromJson),
      itemsTotal: readDouble(json['itemsTotal']),
      deliveryCharge: readDouble(json['deliveryCharge']),
      couponDiscount: readDouble(json['couponDiscount']),
      orderValue: readDouble(json['orderValue']),
      tax: StoreTax.fromJson(readMap(json['tax'])),
      gatewayFee: readDouble(json['gatewayFee']),
      payable: readDouble(json['payable']),
      savings: readDouble(json['savings']),
      expectedDeliveryFrom: readDate(json['expectedDeliveryFrom']),
      expectedDeliveryTo: readDate(json['expectedDeliveryTo']),
      address: address == null ? null : StoreAddress.fromJson(address),
      canPlaceOrder: readBool(json['canPlaceOrder']),
      blockedReason: readStringOrNull(json['blockedReason']),
    );
  }
}

/// P2 — the server-priced order and what Razorpay needs to collect it.
class StorePlacedOrder {
  final String orderNo;
  final String razorpayOrderId;
  final String keyId;

  /// PAISE — what Razorpay takes. [amountRupees] is for the button label.
  final int amountPaise;
  final double amountRupees;
  final String currency;
  final String description;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;

  /// This key's order was already paid (a retry after success).
  final bool alreadyPaid;

  const StorePlacedOrder({
    required this.orderNo,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountPaise,
    required this.amountRupees,
    required this.currency,
    required this.description,
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
    required this.alreadyPaid,
  });

  factory StorePlacedOrder.fromJson(Map<String, dynamic> json) =>
      StorePlacedOrder(
        orderNo: readString(json['orderNo']),
        razorpayOrderId: readString(json['razorpayOrderId']),
        keyId: readString(json['keyId']),
        amountPaise: readInt(json['amountPaise']),
        amountRupees: readDouble(json['amountRupees']),
        currency: readString(json['currency'], 'INR'),
        description: readString(json['description']),
        prefillName: readStringOrNull(json['prefillName']),
        prefillEmail: readStringOrNull(json['prefillEmail']),
        prefillContact: readStringOrNull(json['prefillContact']),
        alreadyPaid: readBool(json['alreadyPaid']),
      );
}

/// P3. `paid: false` comes in three flavours told apart by [message]:
/// "being confirmed", "did not go through" and "being refunded" — see
/// `StoreCheckoutCubit.verify`.
class StoreVerifyResult {
  final bool paid;
  final String message;
  final String orderNo;
  final String? status;

  const StoreVerifyResult({
    required this.paid,
    required this.message,
    required this.orderNo,
    this.status,
  });

  factory StoreVerifyResult.fromJson(Map<String, dynamic> json) =>
      StoreVerifyResult(
        paid: readBool(json['paid']),
        message: readString(json['message']),
        orderNo: readString(json['orderNo']),
        status: readStringOrNull(json['status']),
      );
}
