import 'package:dio/dio.dart';

import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/dio_client.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/utils.dart';

/// What a renewal attempt concluded. The three cases are deliberately
/// distinct because they call for three different responses, and collapsing
/// any two of them is how sessions get thrown away for no reason.
enum TokenRenewal {
  /// A fresh access/refresh pair is stored. Replay the request that 401'd.
  renewed,

  /// The server refused the refresh token itself (401), or there was never
  /// one to present. This — and only this — justifies a logout.
  sessionDead,

  /// The renewal could not be completed: no signal, a timeout, a 5xx, a
  /// response we couldn't parse. Says nothing about whether the session is
  /// alive, so the session is left exactly as it was and the caller's
  /// original error is surfaced instead.
  transientFailure,
}

/// Outcome of one [TokenRefreshService.renew] call.
class TokenRenewalResult {
  final TokenRenewal outcome;

  /// The new access token — set only when [outcome] is
  /// [TokenRenewal.renewed].
  final String? accessToken;

  /// Human-readable reason, for the debug log.
  final String detail;

  const TokenRenewalResult._(this.outcome, this.detail, {this.accessToken});

  const TokenRenewalResult.renewed(String token)
    : outcome = TokenRenewal.renewed,
      accessToken = token,
      detail = 'renewed';

  const TokenRenewalResult.sessionDead(String detail)
    : this._(TokenRenewal.sessionDead, detail);

  const TokenRenewalResult.transientFailure(String detail)
    : this._(TokenRenewal.transientFailure, detail);

  bool get isRenewed => outcome == TokenRenewal.renewed;
}

/// Exchanges a refresh token for a fresh access token, and revokes the
/// token family on sign-out.
///
/// ## Why its own [Dio]
///
/// The shared client carries [AuthInterceptor], which reacts to a 401 by
/// calling *this* service. Refreshing through that client would mean a
/// failed renewal re-entered the interceptor that requested it. This one
/// has no interceptor and no bearer header — see [createBareDioClient].
///
/// ## Single-flight
///
/// A screen typically fires several requests at once, so when the access
/// token dies they all come back 401 together. Every refresh **rotates**
/// the token, so letting four renewals run in parallel would have three of
/// them present an already-retired token — which the backend reads as reuse
/// and answers by revoking the whole family. That turns "renew my session"
/// into "sign me out", which is the precise opposite of the point.
///
/// So there is at most one renewal in flight, and every other caller awaits
/// the same future.
class TokenRefreshService {
  final SessionService _session;
  final Dio _dio;

  /// The renewal currently in progress, or null when idle. Cleared as soon
  /// as the call settles, so the *next* 401 starts a fresh attempt rather
  /// than replaying a stale verdict.
  Future<TokenRenewalResult>? _inFlight;

  TokenRefreshService(this._session, {Dio? dio})
    : _dio = dio ?? createBareDioClient();

  /// Renew the access token, joining the in-flight attempt if there is one.
  Future<TokenRenewalResult> renew() {
    final existing = _inFlight;
    if (existing != null) {
      Utils.debugLog('TokenRefreshService: joining in-flight renewal');
      return existing;
    }
    // `whenComplete` runs before the returned future hands its value to
    // awaiting callers, so the slot is free again the moment this settles.
    final started = _renew().whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  Future<TokenRenewalResult> _renew() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      // A session created before this flow existed (or one the backend
      // couldn't mint a refresh token for). Nothing to renew with, so the
      // 401 is as terminal as it always was.
      Utils.debugLog(
        'TokenRefreshService: no refresh token stored — session is terminal',
      );
      return const TokenRenewalResult.sessionDead('no refresh token stored');
    }

    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.refreshToken,
        data: <String, dynamic>{'refreshToken': refreshToken},
      );

      final payload = _unwrap(response.data);
      final access = payload['accessToken']?.toString() ?? '';
      final rotated = payload['refreshToken']?.toString() ?? '';

      if (access.isEmpty || rotated.isEmpty) {
        // A 200 we can't read. Treating an unrecognised shape as a dead
        // session would sign everyone out the day the envelope changes, so
        // this stays transient and the server keeps the last word.
        Utils.debugLog(
          'TokenRefreshService: renewal returned ${response.statusCode} with '
          'no usable token pair — keeping the session',
        );
        return const TokenRenewalResult.transientFailure(
          'malformed refresh response',
        );
      }

      await _session.saveRenewedTokens(
        accessToken: access,
        refreshToken: rotated,
      );
      Utils.debugLog(
        'TokenRefreshService: access token renewed'
        '${_expiresInSuffix(payload)}',
      );
      return TokenRenewalResult.renewed(access);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401) {
        final code = errorCodeOf(e.response?.data) ?? 'refresh_token_invalid';
        Utils.debugLog(
          'TokenRefreshService: refresh token rejected ($code) — logging out',
        );
        return TokenRenewalResult.sessionDead(code);
      }

      // 404 means the endpoint isn't there — an app build that shipped ahead
      // of the API, or a backend rolled back. Renewal is not merely failing,
      // it does not exist, so treating this as transient would leave the
      // learner in a session that can never recover and never ends: every
      // screen erroring, no route back to the login page. Falling back to the
      // pre-renewal behaviour is the honest answer.
      if (status == 404) {
        Utils.debugLog(
          'TokenRefreshService: refresh endpoint returned 404 — renewal is '
          'unavailable on this backend, treating the session as terminal',
        );
        return const TokenRenewalResult.sessionDead('refresh endpoint absent');
      }
      // Timeout, no signal, 5xx. Losing signal in a lift is not a logout.
      Utils.debugLog(
        'TokenRefreshService: renewal failed transiently (${e.type}, '
        'status $status) — session kept',
      );
      return TokenRenewalResult.transientFailure(e.type.name);
    } catch (e) {
      Utils.debugLog('TokenRefreshService: renewal threw — $e');
      return TokenRenewalResult.transientFailure(e.toString());
    }
  }

  /// Tell the backend to revoke this login's entire refresh-token family.
  ///
  /// Call this **before** [SessionService.clearToken] — it needs the refresh
  /// token that clearToken deletes.
  ///
  /// Never throws and never blocks sign-out. The endpoint always answers 200
  /// when it is reachable, and when it isn't, the learner still wants to be
  /// signed out on this device; the family then dies of old age instead of
  /// being revoked. Refusing to sign someone out because the network is down
  /// would be the worse failure by a wide margin.
  Future<void> revokeSession() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await _dio.post<dynamic>(
        ApiEndpoints.logout,
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      Utils.debugLog('TokenRefreshService: refresh-token family revoked');
    } catch (e) {
      Utils.debugLog(
        'TokenRefreshService: revoke failed, signing out locally anyway — $e',
      );
    }
  }

  /// The renewal payload lives under `data` in the standard envelope, but
  /// accept a flat body too so a contract tweak doesn't read as a failure.
  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is! Map) return const <String, dynamic>{};
    final inner = body['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(body);
  }

  /// Reads the `code` discriminator off a 401 body (`token_expired`,
  /// `unauthorized`, `refresh_token_invalid`). Shared with
  /// [AuthInterceptor] so both read the contract the same way.
  static String? errorCodeOf(dynamic body) {
    if (body is! Map) return null;
    final code = body['code'] ?? body['Code'];
    final text = code?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// `expiresIn` is informational for the client — the 401 is what actually
  /// drives renewal — but it belongs in the log, because it is the one place
  /// the app can see the backend shortening the access-token lifetime.
  String _expiresInSuffix(Map<String, dynamic> payload) {
    final raw = payload['expiresIn'];
    final seconds = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (seconds == null || seconds <= 0) return '';
    return ' (expires in ${seconds ~/ 60} min)';
  }
}
