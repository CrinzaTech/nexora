import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/transaction/data/models/transaction_model.dart';
import 'package:nexora/features/transaction/domain/enums/transaction_filter.dart';
import 'package:nexora/features/transaction/domain/usecases/get_transaction_history_usecase.dart';

part 'transaction_history_state.dart';
part 'transaction_history_cubit.freezed.dart';

/// Drives the Transaction History screen.
///
/// Holds the active payment-status + time filters as cubit state so the
/// chips highlight without the page owning two parallel `setState`s.
/// `load()` / [setPaymentStatus] / [setTimeFilter] all funnel through
/// [_fetch] which builds the API params from the current filter pair.
class TransactionHistoryCubit extends SafeCubit<TransactionHistoryState> {
  final GetTransactionHistoryUseCase getTransactionHistoryUseCase;

  TransactionHistoryCubit({required this.getTransactionHistoryUseCase})
    : super(const TransactionHistoryState.initial());

  /// Last applied filters — used so the page can highlight chips and so
  /// re-issuing a load (after error retry / pull-to-refresh) hits the
  /// same query.
  TransactionPaymentStatus _paymentStatus = TransactionPaymentStatus.all;
  TransactionTimeFilter _timeFilter = TransactionTimeFilter.none;

  TransactionPaymentStatus get paymentStatus => _paymentStatus;
  TransactionTimeFilter get timeFilter => _timeFilter;

  Future<void> load() => _fetch(showLoading: true);

  /// Refetches without flashing `loading` — used by pull-to-refresh so
  /// the existing list stays on screen until the new data arrives.
  Future<void> silentRefresh() => _fetch(showLoading: false);

  Future<void> setPaymentStatus(TransactionPaymentStatus value) {
    if (value == _paymentStatus) return Future.value();
    _paymentStatus = value;
    return _fetch(showLoading: true);
  }

  Future<void> setTimeFilter(TransactionTimeFilter value) {
    if (value == _timeFilter) return Future.value();
    _timeFilter = value;
    return _fetch(showLoading: true);
  }

  Future<void> _fetch({required bool showLoading}) async {
    if (showLoading) emit(const TransactionHistoryState.loading());
    final result = await getTransactionHistoryUseCase(
      paymentStatus: _paymentStatus.apiValue,
      filter: _timeFilter.apiValue,
    );
    result.fold(
      (failure) => emit(TransactionHistoryState.error(failure.message)),
      (list) => emit(TransactionHistoryState.loaded(list)),
    );
  }

  void reset() => emit(const TransactionHistoryState.initial());
}
