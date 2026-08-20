import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Minimal, dependency-free JWT payload reader.
///
/// We only ever need to read a couple of claims out of the student's
/// own access token (never to verify the signature — that is the
/// server's job). Kept tiny on purpose so we don't pull a JWT package
/// for one field.
class JwtUtils {
  JwtUtils._();

  /// Decodes the JWT payload (the middle segment) into a claims map.
  /// Returns an empty map on any malformed input rather than throwing —
  /// callers treat "no claims" the same as "claim absent".
  static Map<String, dynamic> decodePayload(String? token) {
    if (token == null || token.isEmpty) return const {};
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : const {};
    } catch (e) {
      if (kDebugMode) debugPrint('JwtUtils.decodePayload failed: $e');
      return const {};
    }
  }

  /// Extracts the caller's MySQL `app_user.id` (an integer) from their
  /// access token. Live-class hub events carry the peer's `studentId`
  /// as this same id, so equality against this value answers "is this
  /// event about me?".
  ///
  /// The claim key varies by how the backend issues the token. We probe
  /// the common ASP.NET / custom spellings in priority order. If your
  /// backend uses a different claim, add it to [_idClaimKeys] — this is
  /// the single place that mapping lives.
  static int? currentUserId(String? token) {
    final claims = decodePayload(token);
    for (final key in _idClaimKeys) {
      final raw = claims[key];
      if (raw == null) continue;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Claim keys that may hold the numeric user id, in priority order.
  /// ASP.NET Identity emits `nameid` / the long xmlsoap NameIdentifier
  /// URI for `ClaimTypes.NameIdentifier`; custom issuers often add a
  /// plain `id` / `userId` / `appUserId` / `sub`.
  static const List<String> _idClaimKeys = [
    'appUserId',
    'app_user_id',
    'userId',
    'user_id',
    'id',
    'nameid',
    'sub',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
  ];
}
