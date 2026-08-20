part of 'transaction_history_cubit.dart';

@freezed
class TransactionHistoryState with _$TransactionHistoryState {
  const factory TransactionHistoryState.initial() = _Initial;
  const factory TransactionHistoryState.loading() = _Loading;
  const factory TransactionHistoryState.loaded(
    List<TransactionModel> transactions,
  ) = _Loaded;
  const factory TransactionHistoryState.error(String message) = _Error;
}
