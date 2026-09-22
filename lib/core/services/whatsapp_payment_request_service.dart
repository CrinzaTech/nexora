import 'dart:ui' show Rect;

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/utils/share_image.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:nexora/features/profile/domain/usecases/get_org_info_usecase.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outcome of a WhatsApp payment-request attempt, so the caller can pick
/// the right snackbar without this service knowing about widgets.
enum WhatsappPaymentRequestResult {
  /// The share sheet opened with the course thumbnail attached and the
  /// request as its caption. The student picks the org's chat there —
  /// see the class doc for why this path can't pre-address the number.
  sharedWithImage,

  /// The thumbnail couldn't be fetched, so the request went out as a
  /// `wa.me` link addressed straight at the org's number.
  openedChat,

  /// Org-info call failed — [WhatsappPaymentRequestOutcome.message] holds
  /// the failure text from the API.
  lookupFailed,

  /// No thumbnail to attach *and* no support number configured, so there
  /// is neither a way to send the request nor anybody to send it to.
  unavailable,

  /// Nothing on the device could handle the request — typically WhatsApp
  /// not installed.
  launchFailed,
}

class WhatsappPaymentRequestOutcome {
  final WhatsappPaymentRequestResult result;

  /// Failure text for [WhatsappPaymentRequestResult.lookupFailed]; null
  /// otherwise.
  final String? message;

  const WhatsappPaymentRequestOutcome(this.result, {this.message});
}

/// Sends a course purchase to the org's WhatsApp instead of Razorpay,
/// for brands with `BrandingConfig.isPaymentRequestOnWhatsapp` on.
///
/// The thumbnail is attached as a real image rather than pasted as a
/// URL. Course art is served from S3 behind a presigned link — a wall of
/// `?X-Amz-Signature=…` that reads as spam, stops resolving after its
/// 12-hour expiry, and leaks a signed URL into a chat log. An attached
/// image has none of those problems, and WhatsApp lays it out above the
/// caption, so the picture leads and the course name follows.
///
/// That attachment is the reason this goes through the share sheet.
/// WhatsApp's `wa.me` deep link is the only way to pre-address a
/// specific number and it carries **text only** — there is no URL scheme
/// that pre-fills a chat with image bytes. So the two paths trade off,
/// and the choice is made on which one the student is better served by:
///
///   * thumbnail fetched  → share sheet, image + caption. The student
///     picks the org's chat in WhatsApp.
///   * thumbnail missing  → `wa.me/<number>`, addressed straight at the
///     org. With no picture to attach there is nothing to gain from the
///     sheet, so the pre-addressed link wins.
class WhatsappPaymentRequestService {
  final GetOrgInfoUseCase _getOrgInfo;

  WhatsappPaymentRequestService(this._getOrgInfo);

  /// [sharePositionOrigin] is the rect the share sheet anchors to. iPad
  /// presents it as a popover and throws without one, so callers pass
  /// the originating widget's bounds.
  Future<WhatsappPaymentRequestOutcome> requestForCourse(
    CoursePricing pricing, {
    String? couponCode,
    Rect? sharePositionOrigin,
  }) async {
    final result = await _getOrgInfo(whatsappNumber: true);

    // Both branches are async so the `fold` has one return type; the
    // left one just never awaits anything.
    return result.fold<Future<WhatsappPaymentRequestOutcome>>(
      (failure) async => WhatsappPaymentRequestOutcome(
        WhatsappPaymentRequestResult.lookupFailed,
        message: failure.message,
      ),
      (info) async {
        final digits = (info.whatsappNumber ?? '').replaceAll(
          RegExp(r'\D'),
          '',
        );
        final thumb = await ShareImage.fetch(
          pricing.courseImageUrl,
          title: _courseTitle(pricing),
          fallbackName: 'course',
        );

        if (thumb != null) {
          return _shareWithImage(
            pricing,
            thumb: thumb,
            couponCode: couponCode,
            origin: sharePositionOrigin,
          );
        }

        if (digits.isEmpty) {
          return const WhatsappPaymentRequestOutcome(
            WhatsappPaymentRequestResult.unavailable,
          );
        }
        return _openChat(pricing, digits: digits, couponCode: couponCode);
      },
    );
  }

  /// Image + caption through the OS share sheet. WhatsApp renders the
  /// attachment first and the caption beneath it, which is the order we
  /// want: thumbnail, then course name.
  Future<WhatsappPaymentRequestOutcome> _shareWithImage(
    CoursePricing pricing, {
    required XFile thumb,
    required String? couponCode,
    required Rect? origin,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [thumb],
          subject: _courseTitle(pricing),
          text: buildMessage(pricing, couponCode: couponCode),
          sharePositionOrigin: origin,
        ),
      );
      return const WhatsappPaymentRequestOutcome(
        WhatsappPaymentRequestResult.sharedWithImage,
      );
    } catch (e) {
      Utils.debugLog('WhatsApp payment share sheet failed: $e');
      return const WhatsappPaymentRequestOutcome(
        WhatsappPaymentRequestResult.launchFailed,
      );
    }
  }

  /// Text-only fallback, addressed straight at the org's number.
  Future<WhatsappPaymentRequestOutcome> _openChat(
    CoursePricing pricing, {
    required String digits,
    required String? couponCode,
  }) async {
    // Built by hand rather than via `Uri.https`'s query map because that
    // encodes spaces as `+`; `encodeComponent` gives `%20`, which is
    // what wa.me is documented against.
    final text = Uri.encodeComponent(
      buildMessage(
        pricing,
        couponCode: couponCode,
        // No attachment on this path, so the art travels as a link or
        // not at all. It's the ugly presigned URL, but a request with a
        // picture beats one without.
        includeImageLink: true,
      ),
    );
    final uri = Uri.parse('https://wa.me/$digits?text=$text');

    // Checked first so a device without WhatsApp reports back instead of
    // silently doing nothing, matching the support-tile behaviour.
    if (!await canLaunchUrl(uri)) {
      return const WhatsappPaymentRequestOutcome(
        WhatsappPaymentRequestResult.launchFailed,
      );
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return WhatsappPaymentRequestOutcome(
      launched
          ? WhatsappPaymentRequestResult.openedChat
          : WhatsappPaymentRequestResult.launchFailed,
    );
  }

  /// The request body — the caption under the attached thumbnail, or the
  /// whole message on the text-only path.
  ///
  /// Carries nothing about the recipient: on the text-only path the link
  /// is already addressed at the org, and on the share-sheet path the
  /// student has just picked the chat, so naming the number only
  /// restates what they did.
  ///
  /// Public so it can be asserted on in tests without a URL launcher or
  /// a share sheet.
  ///
  /// Identifying the student (name / phone / email, whatever the profile
  /// has) is what makes the request actionable — the org needs to know
  /// which account to unlock once they take the money.
  String buildMessage(
    CoursePricing pricing, {
    String? couponCode,
    bool includeImageLink = false,
  }) {
    final profile = _currentProfile();

    final lines = <String>[
      'Hi, I would like to enrol in this course and complete the payment.',
      '',
      '📚 Course: ${_courseTitle(pricing)}',
      '💰 Amount: ₹${Utils.formatPrice(pricing.totalPayable)}',
    ];

    if (pricing.expiryDetails.trim().isNotEmpty) {
      lines.add('⏳ ${pricing.expiryDetails.trim()}');
    }
    if (couponCode != null && couponCode.trim().isNotEmpty) {
      lines.add('🎟️ Coupon: ${couponCode.trim()}');
    }
    if (includeImageLink && pricing.courseImageUrl.trim().isNotEmpty) {
      lines.add('🖼️ ${pricing.courseImageUrl.trim()}');
    }

    final who = _studentLines(profile);
    if (who.isNotEmpty) {
      lines
        ..add('')
        ..add('My details:')
        ..addAll(who);
    }

    lines
      ..add('')
      ..add('Please share the payment details. Thank you!');

    return lines.join('\n');
  }

  String _courseTitle(CoursePricing pricing) =>
      pricing.courseTitle.trim().isEmpty
      ? 'Course #${pricing.courseId}'
      : pricing.courseTitle.trim();

  List<String> _studentLines(UserProfileModel? profile) {
    if (profile == null) return const [];
    return [
      if (profile.name?.trim().isNotEmpty ?? false)
        '👤 ${profile.name!.trim()}',
      if (profile.phoneNumber?.trim().isNotEmpty ?? false)
        '📞 ${profile.phoneNumber!.trim()}',
      if (profile.email?.trim().isNotEmpty ?? false)
        '✉️ ${profile.email!.trim()}',
    ];
  }

  /// Reads the live profile off the global ProfileCubit, the same way
  /// the Razorpay prefill does. Null when the profile hasn't loaded —
  /// the message then simply omits the "My details" block.
  UserProfileModel? _currentProfile() => sl<ProfileCubit>().state.maybeWhen(
    loaded: (p) => p,
    updated: (p) => p,
    updating: (p) => p,
    orElse: () => null,
  );
}
