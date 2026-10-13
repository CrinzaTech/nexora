import 'store_common_model.dart';

/// The card every product list uses (home rails, C3, search).
class StoreProductCard {
  final String productId;
  final String title;
  final String? shortDescription;
  final String? categoryName;
  final String? imageUrl;
  final double mrp;
  final double sellingPrice;
  final int discountPercent;
  final double ratingAvg;
  final int ratingCount;
  final bool inStock;

  /// Set only when stock is low (≤ 5): "Only 3 left".
  final int? onlyLeft;
  final bool isTrending;
  final bool isFeatured;
  final bool isNew;
  final bool freeDelivery;
  final bool hasVideo;

  const StoreProductCard({
    required this.productId,
    required this.title,
    this.shortDescription,
    this.categoryName,
    this.imageUrl,
    required this.mrp,
    required this.sellingPrice,
    required this.discountPercent,
    required this.ratingAvg,
    required this.ratingCount,
    required this.inStock,
    this.onlyLeft,
    this.isTrending = false,
    this.isFeatured = false,
    this.isNew = false,
    this.freeDelivery = false,
    this.hasVideo = false,
  });

  /// Strike-through MRP and the "% off" badge only show with a discount.
  bool get hasDiscount => discountPercent > 0;

  factory StoreProductCard.fromJson(Map<String, dynamic> json) =>
      StoreProductCard(
        productId: readString(json['productId']),
        title: readString(json['title']),
        shortDescription: readStringOrNull(json['shortDescription']),
        categoryName: readStringOrNull(json['categoryName']),
        imageUrl: readStringOrNull(json['imageUrl']),
        mrp: readDouble(json['mrp']),
        sellingPrice: readDouble(json['sellingPrice']),
        discountPercent: readInt(json['discountPercent']),
        ratingAvg: readDouble(json['ratingAvg']),
        ratingCount: readInt(json['ratingCount']),
        inStock: readBool(json['inStock'], true),
        onlyLeft: readIntOrNull(json['onlyLeft']),
        isTrending: readBool(json['isTrending']),
        isFeatured: readBool(json['isFeatured']),
        isNew: readBool(json['isNew']),
        freeDelivery: readBool(json['freeDelivery']),
        hasVideo: readBool(json['hasVideo']),
      );
}

class StoreCategory {
  final int id;
  final int? parentId;
  final String name;
  final String slug;
  final String? iconUrl;
  final int productCount;

  const StoreCategory({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.iconUrl,
    required this.productCount,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) => StoreCategory(
    id: readInt(json['id']),
    parentId: readIntOrNull(json['parentId']),
    name: readString(json['name']),
    slug: readString(json['slug']),
    iconUrl: readStringOrNull(json['iconUrl']),
    productCount: readInt(json['productCount']),
  );
}

/// C1 — the store's landing payload. Each rail holds at most 10 cards and
/// is hidden when empty.
class StoreHome {
  final String storeName;
  final List<StoreProductCard> featured;
  final List<StoreProductCard> trending;
  final List<StoreProductCard> newArrivals;
  final List<StoreProductCard> bestsellers;
  final List<StoreCategory> categories;
  final int cartCount;

  const StoreHome({
    required this.storeName,
    required this.featured,
    required this.trending,
    required this.newArrivals,
    required this.bestsellers,
    required this.categories,
    required this.cartCount,
  });

  factory StoreHome.fromJson(Map<String, dynamic> json) => StoreHome(
    storeName: readString(json['storeName'], 'Store'),
    featured: readList(json['featured'], StoreProductCard.fromJson),
    trending: readList(json['trending'], StoreProductCard.fromJson),
    newArrivals: readList(json['newArrivals'], StoreProductCard.fromJson),
    bestsellers: readList(json['bestsellers'], StoreProductCard.fromJson),
    categories: readList(json['categories'], StoreCategory.fromJson),
    cartCount: readInt(json['cartCount']),
  );
}

class StoreMedia {
  final bool isVideo;
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final double? durationSec;

  const StoreMedia({
    required this.isVideo,
    required this.url,
    this.thumbUrl,
    this.width,
    this.height,
    this.durationSec,
  });

  factory StoreMedia.fromJson(Map<String, dynamic> json) => StoreMedia(
    isVideo: readString(json['type']).toLowerCase() == 'video',
    url: readString(json['url']),
    thumbUrl: readStringOrNull(json['thumbUrl']),
    width: readIntOrNull(json['width']),
    height: readIntOrNull(json['height']),
    durationSec: readDoubleOrNull(json['durationSec']),
  );
}

class StoreDelivery {
  final double charge;
  final bool free;
  final int minDays;
  final int maxDays;

  /// Calendar dates (IST). "Delivery by 15–19 Oct".
  final DateTime? from;
  final DateTime? to;

  const StoreDelivery({
    required this.charge,
    required this.free,
    required this.minDays,
    required this.maxDays,
    this.from,
    this.to,
  });

  factory StoreDelivery.fromJson(Map<String, dynamic> json) => StoreDelivery(
    charge: readDouble(json['charge']),
    free: readBool(json['free']),
    minDays: readInt(json['minDays']),
    maxDays: readInt(json['maxDays']),
    from: readDate(json['from']),
    to: readDate(json['to']),
  );
}

class StoreRatingSummary {
  final double average;
  final int count;

  /// Counts for 1★ to 5★, in that order.
  final List<int> stars;

  const StoreRatingSummary({
    required this.average,
    required this.count,
    required this.stars,
  });

  factory StoreRatingSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['stars'];
    final stars = raw is List ? [for (final s in raw) readInt(s)] : <int>[];
    return StoreRatingSummary(
      average: readDouble(json['average']),
      count: readInt(json['count']),
      // Padded so a short array can't index out of range in the bars.
      stars: [...stars, ...List.filled((5 - stars.length).clamp(0, 5), 0)],
    );
  }
}

class StoreReview {
  final int id;
  final String learnerName;
  final int rating;
  final String? comment;
  final bool isPinned;
  final String? sellerReply;
  final DateTime? repliedAt;
  final DateTime? createdAt;

  const StoreReview({
    required this.id,
    required this.learnerName,
    required this.rating,
    this.comment,
    this.isPinned = false,
    this.sellerReply,
    this.repliedAt,
    this.createdAt,
  });

  factory StoreReview.fromJson(Map<String, dynamic> json) => StoreReview(
    id: readInt(json['id']),
    learnerName: readString(json['learnerName'], 'Learner'),
    rating: readInt(json['rating']),
    comment: readStringOrNull(json['comment']),
    isPinned: readBool(json['isPinned']),
    sellerReply: readStringOrNull(json['sellerReply']),
    repliedAt: readDate(json['repliedAt']),
    createdAt: readDate(json['createdAt']),
  );
}

/// C4 — everything on the card, plus the product page extras.
class StoreProductDetail {
  final StoreProductCard card;
  final String description;
  final String? brand;
  final String? countryOfOrigin;
  final String? parentCategoryName;

  /// Photos first (the first is the cover), then the video if any.
  final List<StoreMedia> media;

  /// Already capped by stock — the stepper's maximum.
  final int maxQtyPerOrder;
  final StoreDelivery? delivery;
  final bool isCancellable;
  final bool isReturnable;
  final int returnWindowDays;
  final StoreCover? warranty;
  final StoreCover? guarantee;
  final StoreRatingSummary rating;
  final List<StoreReview> topReviews;
  final int cartQty;
  final String? sellerName;

  const StoreProductDetail({
    required this.card,
    required this.description,
    this.brand,
    this.countryOfOrigin,
    this.parentCategoryName,
    required this.media,
    required this.maxQtyPerOrder,
    this.delivery,
    required this.isCancellable,
    required this.isReturnable,
    required this.returnWindowDays,
    this.warranty,
    this.guarantee,
    required this.rating,
    required this.topReviews,
    required this.cartQty,
    this.sellerName,
  });

  String get productId => card.productId;

  factory StoreProductDetail.fromJson(Map<String, dynamic> json) {
    final delivery = readMapOrNull(json['delivery']);
    return StoreProductDetail(
      card: StoreProductCard.fromJson(json),
      description: readString(json['description']),
      brand: readStringOrNull(json['brand']),
      countryOfOrigin: readStringOrNull(json['countryOfOrigin']),
      parentCategoryName: readStringOrNull(json['parentCategoryName']),
      media: readList(
        json['media'],
        StoreMedia.fromJson,
      ).where((m) => m.url.isNotEmpty).toList(),
      maxQtyPerOrder: readInt(json['maxQtyPerOrder'], 1),
      delivery: delivery == null ? null : StoreDelivery.fromJson(delivery),
      isCancellable: readBool(json['isCancellable']),
      isReturnable: readBool(json['isReturnable']),
      returnWindowDays: readInt(json['returnWindowDays']),
      warranty: StoreCover.fromJson(json['warranty']),
      guarantee: StoreCover.fromJson(json['guarantee']),
      rating: StoreRatingSummary.fromJson(readMap(json['rating'])),
      topReviews: readList(json['topReviews'], StoreReview.fromJson),
      cartQty: readInt(json['cartQty']),
      sellerName: readStringOrNull(json['sellerName']),
    );
  }
}

/// C3 sort keys, as the API spells them.
enum StoreSort {
  newest('new', 'Newest first'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low'),
  popular('popular', 'Most popular'),
  rating('rating', 'Top rated');

  final String wire;
  final String label;
  const StoreSort(this.wire, this.label);

  static StoreSort fromWire(String? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => StoreSort.newest);
}

/// The filters behind one C3 listing.
class StoreProductQuery {
  final int? categoryId;
  final String? q;
  final StoreSort sort;
  final double? minPrice;
  final double? maxPrice;

  const StoreProductQuery({
    this.categoryId,
    this.q,
    this.sort = StoreSort.newest,
    this.minPrice,
    this.maxPrice,
  });

  bool get hasPriceFilter => minPrice != null || maxPrice != null;

  StoreProductQuery copyWith({
    int? categoryId,
    String? q,
    StoreSort? sort,
    double? Function()? minPrice,
    double? Function()? maxPrice,
  }) {
    return StoreProductQuery(
      categoryId: categoryId ?? this.categoryId,
      q: q ?? this.q,
      sort: sort ?? this.sort,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
    );
  }

  Map<String, dynamic> toQuery({required int pageNo, required int pageSize}) {
    final search = q?.trim() ?? '';
    return {
      'categoryId': ?categoryId,
      // The API ignores fewer than 2 letters; not sending them keeps the
      // request honest about what it is asking for.
      if (search.length >= 2) 'q': search,
      'sort': sort.wire,
      'minPrice': ?minPrice,
      'maxPrice': ?maxPrice,
      'pageNo': pageNo,
      'pageSize': pageSize,
    };
  }
}
