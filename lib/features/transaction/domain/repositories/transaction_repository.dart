import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/transaction/data/models/receipt_model.dart';
import 'package:nexora/features/transaction/data/models/transaction_model.dart';

abstract class TransactionRepository {
  /// Fetches the user's transaction history. Both filters are optional —
  /// pass `null` to omit the corresponding query param.
  Future<Either<Failure, List<TransactionModel>>> getHistory({
    String? paymentStatus,
    String? filter,
    String? itemType,
  });

  /// Downloads the HTML receipt for one of the caller's own payment
  /// transactions. Fails with a 400/404-mapped [Failure] when the
  /// transaction doesn't exist, isn't the caller's, or wasn't paid.
  Future<Either<Failure, ReceiptModel>> downloadReceipt(int transactionId);

  /// Downloads a store order's document: the tax invoice / bill of supply
  /// once it has shipped, a payment receipt before that. Same HTML shape
  /// as [downloadReceipt].
  Future<Either<Failure, ReceiptModel>> downloadStoreInvoice(String orderNo);
}
