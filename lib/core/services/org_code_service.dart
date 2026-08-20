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
