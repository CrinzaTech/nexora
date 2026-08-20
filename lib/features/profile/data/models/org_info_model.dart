/// Response model for `GET /api/v1/organization-info`.
///
/// All three fields are nullable — the server only populates the one
/// corresponding to the query param that was `true` in the request.
///
///   ?whatsappNumber=true    → [whatsappNumber] is set
///   ?termsAndCondition=true → [termsAndConditionUrl] is set
///   ?refundPolicy=true      → [refundPolicyUrl] is set
class OrgInfoModel {
  final String? whatsappNumber;
  final String? termsAndConditionUrl;
  final String? refundPolicyUrl;

  /// Which support channel this org runs. `true` — the default —
  /// routes "Contact for Support" to WhatsApp; `false` routes it to
  /// in-app personal chat with the org's faculty instead.
  ///
  /// Defaults to `true` when the key is absent so an older backend, or
  /// a response for a different query flag, keeps the existing WhatsApp
  /// behaviour rather than silently rerouting every org to chat.
  final bool allowWhatsappSupport;

  const OrgInfoModel({
    this.whatsappNumber,
    this.termsAndConditionUrl,
    this.refundPolicyUrl,
    this.allowWhatsappSupport = true,
  });

  factory OrgInfoModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return OrgInfoModel(
      whatsappNumber: data['whatsappNumber'] as String?,
      termsAndConditionUrl: data['termsAndConditionUrl'] as String?,
      refundPolicyUrl: data['refundPolicyUrl'] as String?,
      // Tolerant of a stringified bool — this flag decides which screen
      // the user lands on, so a serialiser quirk must not flip it.
      allowWhatsappSupport: _toBool(data['allowWhatsappSupport']),
    );
  }
}

bool _toBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final v = raw.trim().toLowerCase();
    if (v == 'false' || v == '0') return false;
    if (v == 'true' || v == '1') return true;
  }
  // Absent or unparseable — keep WhatsApp, the pre-existing behaviour.
  return true;
}
