import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// C1 — rails, categories and the cart badge.
class GetStoreHomeUseCase {
  final StoreRepository repository;

  GetStoreHomeUseCase(this.repository);

  Future<Either<Failure, StoreHome>> call() => repository.getHome();
}

/// C3 — list, filter, sort, search. Paged.
class GetStoreProductsUseCase {
  final StoreRepository repository;

  GetStoreProductsUseCase(this.repository);

  Future<Either<Failure, StorePage<StoreProductCard>>> call(
    StoreProductQuery query, {
    int pageNo = 1,
    int pageSize = 20,
  }) => repository.getProducts(query, pageNo: pageNo, pageSize: pageSize);
}

/// C4 — the product page.
class GetStoreProductUseCase {
  final StoreRepository repository;

  GetStoreProductUseCase(this.repository);

  Future<Either<Failure, StoreProductDetail>> call(String productId) =>
      repository.getProduct(productId);
}

/// C5 — approved review comments. Paged.
class GetStoreReviewsUseCase {
  final StoreRepository repository;

  GetStoreReviewsUseCase(this.repository);

  Future<Either<Failure, StorePage<StoreReview>>> call(
    String productId, {
    int pageNo = 1,
    int pageSize = 20,
  }) => repository.getReviews(productId, pageNo: pageNo, pageSize: pageSize);
}
