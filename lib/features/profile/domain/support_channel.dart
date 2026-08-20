import 'package:nexora/features/profile/data/models/org_info_model.dart';

/// Where "Contact for Support" should take the user.
enum SupportChannel {
  /// Org runs WhatsApp support and has a number configured.
  whatsapp,

  /// Org runs in-app 1-to-1 chat with its faculty instead.
  personalChat,

  /// Org runs WhatsApp support but has no number configured — nothing to
  /// open, so the caller shows "not available right now".
  unavailable,
}

/// The single place the support-channel decision is made.
///
/// This exists because the decision has more than one call site — the
/// Profile screen's tile and the web footer's "Contact Support" link —
/// and duplicating the `if (!allowWhatsappSupport)` branch across them
/// meant one of them could silently keep the old behaviour. It did: the
/// footer went on opening WhatsApp for orgs that had switched to
/// personal chat, which only showed up on wide windows because that is
/// the only place the footer renders.
///
/// Any new entry point should call this rather than re-reading the flag.
SupportChannel resolveSupportChannel(OrgInfoModel info) {
  if (!info.allowWhatsappSupport) return SupportChannel.personalChat;
  final number = info.whatsappNumber;
  if (number == null || number.trim().isEmpty) {
    return SupportChannel.unavailable;
  }
  return SupportChannel.whatsapp;
}

/// `https://wa.me/<digits>` for [OrgInfoModel.whatsappNumber].
///
/// Non-digits are stripped so the link works whatever format the server
/// stores the number in. Only meaningful when [resolveSupportChannel]
/// returned [SupportChannel.whatsapp].
Uri whatsappUriFor(OrgInfoModel info) {
  final digits = (info.whatsappNumber ?? '').replaceAll(RegExp(r'\D'), '');
  return Uri.parse('https://wa.me/$digits');
}
