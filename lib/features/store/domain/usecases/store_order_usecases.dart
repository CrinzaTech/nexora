import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/domain/repositories/store_repository.dart';

/// O1 — my orders, by group. Paged.
class GetStoreOrdersUseCase {
  final StoreRepository repository;

  GetStoreOrdersUseCase(this.repository);

  Future<Either<Failure, StorePage<StoreOrderSummary>>> call(
    StoreOrderGroup group, {
    int pageNo = 1,
    int pageSize = 10,
  }) => repository.getOrders(group, pageNo: pageNo, pageSize: pageSize);
}

/// O2 — detail, tracking and timeline.
class GetStoreOrderUseCase {
  final StoreRepository repository;

  GetStoreOrderUseCase(this.repository);

  Future<Either<Failure, StoreOrderDetail>> call(String orderNo) =>
      repository.getOrder(orderNo);
}

/// O3 — before shipping only; refunds in full. Answers with the message.
class CancelStoreOrderUseCase {
  final StoreRepository repository;

  CancelStoreOrderUseCase(this.repository);

  Future<Either<Failure, String>> call(String orderNo, {String? reason}) =>
      repository.cancelOrder(orderNo, reason: reason);
}

/// O4 — "I received it". Starts warranty and guarantee, unlocks Rate.
class ConfirmStoreOrderReceivedUseCase {
  final StoreRepository repository;

  ConfirmStoreOrderReceivedUseCase(this.repository);

  Future<Either<Failure, String>> call(String orderNo) =>
      repository.confirmReceived(orderNo);
}

/// O5 — one review per item.
class ReviewStoreItemUseCase {
  final StoreRepository repository;

  ReviewStoreItemUseCase(this.repository);

  Future<Either<Failure, String>> call(
    String orderNo,
    int itemId, {
    required int rating,
    String? comment,
  }) =>
      repository.reviewItem(orderNo, itemId, rating: rating, comment: comment);
}
