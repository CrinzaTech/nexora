import 'package:intl/intl.dart';

/// Display formatting for Store figures and dates. Formatting only — every
/// amount is shown exactly as the server sent it.
abstract final class StoreFormat {
  static final _whole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _paise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// "₹540", "₹1,101.60", "₹1,20,000".
  static String money(double amount) => amount == amount.truncateToDouble()
      ? _whole.format(amount)
      : _paise.format(amount);

  /// "15 Oct 2026"
  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  /// "15 Oct"
  static String shortDate(DateTime d) => DateFormat('d MMM').format(d);

  /// "10 Oct 2026, 2:42 PM"
  static String dateTime(DateTime d) =>
      DateFormat('d MMM yyyy, h:mm a').format(d);

  /// "15 to 19 Oct", "29 Oct to 2 Nov", or "15 Oct": the delivery window.
  static String? dateRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) return null;
    if (from == null || to == null) return shortDate((from ?? to)!);
    if (from.year == to.year && from.month == to.month) {
      if (from.day == to.day) return shortDate(from);
      return '${from.day} to ${to.day} ${DateFormat('MMM').format(to)}';
    }
    return '${shortDate(from)} to ${shortDate(to)}';
  }

  /// "12-month", "2-year", "18-month".
  static String coverLength(int months) {
    if (months > 0 && months % 12 == 0) {
      final years = months ~/ 12;
      return '$years-year';
    }
    return '$months-month';
  }

  /// "4.6"
  static String rating(double r) => r.toStringAsFixed(1);

  /// "38", "1.2k"
  static String count(int n) {
    if (n < 1000) return '$n';
    final k = n / 1000;
    return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k';
  }
}
