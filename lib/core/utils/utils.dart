import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Common utility functions
class Utils {
  Utils._();

  /// Debug logging - only logs in debug mode
  static void debugLog(String message) {
    if (kDebugMode) {
      print('[CrinzaApp] $message');
    }
  }

  /// Joined At Date Formatter
  /// Formats a DateTime string into "Joined At Month Year" format.
  /// Example: "2023-01-15T12:34:56Z" → "Joined At Jan 2023"
  static String formatJoinedAt(String? joinedAt) {
    try {
      if (joinedAt == null || joinedAt.isEmpty) {
        return "Joined At N/A";
      }
      final date = DateTime.parse(joinedAt);
      return "Joined At ${DateFormat('dd, MMM yyyy').format(date)}";
    } catch (e) {
      debugLog("Error parsing joinedAt date: $e");
      return "Joined At Unknown";
    }
  }

  /// Format a date as DD/MMM/YYYY (e.g. 15/Jan/2023).
  static String formatDdMmmYyyy(
    DateTime? date, {
    String fallback = 'DD/MMM/YYYY',
  }) {
    if (date == null) return fallback;
    return DateFormat('dd/MMM/yyyy').format(date);
  }

  /// Stable cache key for a network image URL.
  ///
  /// Strips the query string and fragment so signed/presigned URLs
  /// (whose signatures rotate) still resolve to the same cache entry.
  /// We slice on the raw string instead of `Uri.replace(query: '')` so
  /// the result has no trailing `?` — keeps cache keys identical for
  /// URLs that arrived with or without query params.
  static String imageCacheKey(String url) {
    final qIndex = url.indexOf('?');
    final hIndex = url.indexOf('#');
    int cutoff = url.length;
    if (qIndex >= 0) cutoff = qIndex;
    if (hIndex >= 0 && hIndex < cutoff) cutoff = hIndex;
    return url.substring(0, cutoff);
  }

  /// Get current timestamp in milliseconds
  static int get currentTimestamp => DateTime.now().millisecondsSinceEpoch;

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number (basic validation)
  static bool isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''));
  }

  /// Returns up to two initials from [name]:
  ///   • First char of the first word
  ///   • First char of the second word (after the first space), if present
  /// Falls back to a single '?' when the name is empty.
  static String getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first[0].toUpperCase();
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '$first${parts[1][0].toUpperCase()}';
    }
    return first;
  }

  /// Capitalize first letter of string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Convert a string to Title Case — first letter of every whitespace-separated
  /// word becomes uppercase, the rest become lowercase.
  ///
  /// Examples:
  /// - "male"          → "Male"
  /// - "JOHN DOE"      → "John Doe"
  /// - "hello world"   → "Hello World"
  /// - "  the\tquick " → "The Quick"
  ///
  /// Returns an empty string for null or empty input.
  static String toTitleCase(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Format review count with k suffix (e.g., 6310 -> "6.3k reviews")
  static String formatReviewCount(int count) {
    if (count <= 0) {
      return "No reviews";
    }
    if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k reviews";
    }
    return "$count reviews";
  }

  /// Format price with comma separators (e.g., 5200 -> "5,200")
  static String formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      return NumberFormat('#,##0').format(price);
    } else {
      return NumberFormat('#,##0.00').format(price);
    }
  }

  /// Default Bottom Space for all the screens to avoid content getting hidden behind the bottom navigation bar
  static Widget defaultBottomSpace({double extraSpace = 75}) {
    // We add more extra space because the FloatingNavbar sits inside a SafeArea
    // and is floating, meaning it can reach ~100px from the bottom on iPhones.
    return SizedBox(height: kBottomNavigationBarHeight + extraSpace);
  }
}
