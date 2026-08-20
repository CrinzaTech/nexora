import 'package:nexora/features/transaction/data/models/transaction_model.dart';

/// Backend-mapped payment-status filter for `GET /transaction-history`.
///
/// `all` → don't send the query param. `completed` → `SUCCESS`,
/// `failed` → `FAILED`, `pending` → `PENDING`. The repo layer reads
/// [apiValue] directly so the page never has to deal with the wire form.
enum TransactionPaymentStatus {
  all,
  completed,
  failed,
  pending;

  /// Display label for the filter chip.
  String get label {
    switch (this) {
      case TransactionPaymentStatus.all:
        return 'All';
      case TransactionPaymentStatus.completed:
        return 'Completed';
      case TransactionPaymentStatus.failed:
        return 'Failed';
      case TransactionPaymentStatus.pending:
        return 'Pending';
    }
  }

  /// Wire value sent as the `PaymentStatus` query param. `null` for
  /// [all] so the repo can omit the param entirely.
  String? get apiValue {
    switch (this) {
      case TransactionPaymentStatus.all:
        return null;
      case TransactionPaymentStatus.completed:
        return 'SUCCESS';
      case TransactionPaymentStatus.failed:
        return 'FAILED';
      case TransactionPaymentStatus.pending:
        return 'PENDING';
    }
  }

  /// Reverse mapping — used by the page to highlight whichever chip
  /// matches a backend status (e.g. when navigating back into the
  /// page with a pre-selected filter).
  static TransactionPaymentStatus fromStatus(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return TransactionPaymentStatus.completed;
      case TransactionStatus.failed:
        return TransactionPaymentStatus.failed;
      case TransactionStatus.pending:
        return TransactionPaymentStatus.pending;
      case TransactionStatus.refunded:
      case TransactionStatus.unknown:
        return TransactionPaymentStatus.all;
    }
  }
}

/// Time-window filter for `GET /transaction-history`.
///
/// `none` → don't send the query param.
enum TransactionTimeFilter {
  none,
  lastWeek,
  thisMonth,
  lastMonth;

  String get label {
    switch (this) {
      case TransactionTimeFilter.none:
        return 'Date';
      case TransactionTimeFilter.lastWeek:
        return 'Last 7 Days';
      case TransactionTimeFilter.thisMonth:
        return 'This Month';
      case TransactionTimeFilter.lastMonth:
        return 'Last Month';
    }
  }

  /// Label used inside the popup menu — `none` reads as "All time"
  /// there (it's the "clear filter" option), whereas the pill itself
  /// uses [label] which keeps "Date" as the placeholder.
  String get popupLabel {
    if (this == TransactionTimeFilter.none) return 'All time';
    return label;
  }

  /// Wire value sent as the `Filter` query param. `null` for [none].
  String? get apiValue {
    switch (this) {
      case TransactionTimeFilter.none:
        return null;
      case TransactionTimeFilter.lastWeek:
        return 'LAST_WEEK';
      case TransactionTimeFilter.thisMonth:
        return 'THIS_MONTH';
      case TransactionTimeFilter.lastMonth:
        return 'LAST_MONTH';
    }
  }
}
