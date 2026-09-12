import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Holds the org code for the current session.
///
/// When the user completes the Org Code page the validated code is
/// written here via [setOrgCode]. Every OTP use case then reads
/// [effectiveOrgCode] instead of re-reading `.env` directly, so the
/// user-entered code is used everywhere automatically.
///
/// On skip (or when the Org Code page is not shown), [_userOrgCode]
/// stays `null` and [effectiveOrgCode] falls back to the `.env` value.
class OrgCodeService {
  OrgCodeService._();

  static final OrgCodeService instance = OrgCodeService._();

  String? _userOrgCode;

  /// Whether a validated org code has been explicitly set this session.
  bool get hasUserOrgCode => _userOrgCode != null;

  /// The org code to send to the backend.
  ///
  /// Priority order:
  ///  1. User-entered & validated code from the Org Code page.
  ///  2. `ORG_ID` value from `.env` (the pre-ship default).
  String? get effectiveOrgCode => _userOrgCode ?? dotenv.env['ORG_ID'];

  /// The same value, for **display**, but never throws.
  ///
  /// `dotenv.env` throws [NotInitializedError] when `.env` hasn't been
  /// loaded. `main()` loads it before `runApp`, so [effectiveOrgCode] is
  /// safe on the auth path and deliberately keeps throwing there — a
  /// missing `.env` is a build misconfiguration, and every OTP call
  /// silently going out without an org code would be far harder to
  /// diagnose than a crash at startup.
  ///
  /// A profile header is a different matter: it should not be able to
  /// take down the screen over a value it only renders as a label. This
  /// returns `null` instead, and the caller omits the field.
  String? get displayOrgCode {
    if (_userOrgCode != null) return _userOrgCode;
    return dotenv.isInitialized ? dotenv.env['ORG_ID'] : null;
  }

  /// Store a validated org code. Should only be called after the
  /// `/api/v1/validate-org-code` endpoint confirms `isValid: true`.
  void setOrgCode(String code) {
    _userOrgCode = code;
  }

  /// Clear the stored org code (e.g. on logout / session reset).
  void clear() {
    _userOrgCode = null;
  }
}
