import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether the current platform may sell anything inside the app.
///
/// Exists for App Store Review Guideline 3.1.1: digital content (courses,
/// online webinars) unlocked inside an iOS app must be sold through
/// Apple's In-App Purchase, and the app may not carry buttons, prices or
/// messages that point the user at any other way of paying.
///
/// Crinza sells through Razorpay (and, for some brands, a WhatsApp
/// payment request). Rather than route iOS purchases through IAP, the
/// iOS build is a *consumption* app: learners open what they already
/// own, free content stays free, and every price, Buy / Enroll CTA,
/// plan picker, coupon sheet and payment hand-off is hidden. Locked
/// content reads as neutrally unavailable — never "buy it elsewhere",
/// which would itself be the steering 3.1.1 forbids.
///
/// Android and web are untouched: everything below is `true` there.
abstract final class PaymentPolicy {
  /// `false` on iOS — no prices, no paid-purchase CTAs, no checkout.
  /// Free enrolment still works, since nothing is being sold.
  static bool get allowsPurchases => !_isApple;

  /// The one line locked content shows where purchases are disallowed.
  /// Deliberately says nothing about how or where to get access.
  static const String unavailableMessage =
      'This content is not available right now.';

  static bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}
