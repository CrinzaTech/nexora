import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/transaction/data/models/receipt_model.dart';
import 'package:nexora/features/transaction/domain/repositories/transaction_repository.dart';

class DownloadReceiptUseCase {
  final TransactionRepository repository;

  DownloadReceiptUseCase(this.repository);

  Future<Either<Failure, ReceiptModel>> call(int transactionId) {
    return repository.downloadReceipt(transactionId);
  }
}
