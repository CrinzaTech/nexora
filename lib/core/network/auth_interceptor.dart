import 'package:dio/dio.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/network/token_refresh_service.dart';
import 'package:nexora/core/router/app_router.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Injects the Bearer token into every outgoing request and centralizes
/// 401 handling.
///
/// A 401 on a request that carried the current main session token no longer
/// ends the session. It asks [TokenRefreshService] for a fresh access token
/// and replays the request. Only two things still sign the learner out: the
/// backend refusing the *refresh* token, and a session that has no refresh
/// token to offer. Every other 401 — unauthenticated endpoints, chat-token
/// calls, requests that outlived the token they were sent with, a transient
/// network failure during renewal — is passed through to the caller with the
/// session left alone.
///
/// Token source: [SessionService] — an in-memory cache hydrated from secure
/// storage (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on
/// Android) during app startup.
class AuthInterceptor extends Interceptor {
  /// `extra` key holding the session token a request actually went out
  /// with.
  ///
  /// Recorded at send time rather than re-derived in [onError], because by
  /// the time a 401 comes back the cached token may already have been
  /// rotated by a renewal this request knows nothing about. Comparing the
  /// header against the *current* token would then misread "sent with the
  /// token that has since been replaced" as "sent with somebody else's
  /// token", and quietly drop a request that only needed replaying.
  static const String _sentTokenKey = 'crinza.auth.sentToken';

  /// `extra` key marking a request that has already been replayed once
  /// after a successful renewal. The stop on the recursion: a replay that
  /// 401s again never triggers a second renewal.
  static const String _replayedKey = 'crinza.auth.replayed';

  /// Re-entry guard: if a screen fires several requests in parallel they may
  /// all come back with 401 once the session dies for real. Without this flag
  /// we'd stack multiple `router.go(login)` calls and clearToken() races.
  static bool _logoutInProgress = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Respect an Authorization header that the caller already set — this
    // is how chat-feature endpoints pass the dedicated chat JWT instead
    // of the main access token. Without this guard the interceptor
    // would unconditionally clobber the chat token with the main one.
    //
    // It is also how a replayed request keeps the freshly renewed token
    // that [_rebuild] stamped onto it.
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    final token = _getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_sentTokenKey] = token;
    }
    handler.next(options);
  }

  /// The workshop-pass family, exempt from the renew/logout path below.
  ///
  /// A 401 here is **not** evidence the session died. The pass screen
  /// fetches the pass and downloads it with the same token seconds
  /// apart, so a 401 on one and not the other says something specific to
  /// that endpoint, not something about the session.
  ///
  /// Signing the attendee out on it is the worst possible response: they
  /// land on the login screen, sign back in, tap download, and are
  /// thrown out again — a loop with no exit, and they lose the rest of
  /// their session to an endpoint they were only trying to save a PDF
  /// from.
  ///
  /// Suppressing the logout costs nothing. If the session genuinely has
  /// expired, the very next ordinary call — any screen, any refresh —
  /// answers 401 and renews properly. This only declines to infer
  /// anything about the session from the one endpoint least qualified to
  /// report on it.
  static final RegExp _workshopPassPath = RegExp(
    r'^/api/v1/workshop-pass/',
  );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status != 401) {
      handler.next(err);
      return;
    }

    // See [_workshopPassPath]: the caller gets the 401 and shows the
    // reason; the session is left alone.
    if (_workshopPassPath.hasMatch(err.requestOptions.uri.path)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final sentToken = options.extra[_sentTokenKey] as String?;

    // Only a 401 on a request that carried the main session token says
    // anything about the session.
    //
    //  • Nothing recorded → either no Authorization header at all
    //    (/send-otp, /verify-otp and friends — a credential failure, not
    //    session expiry), or a header the caller set itself, which means a
    //    chat-token call. Those JWTs expire on their own schedule; killing
    //    the whole session over one is how a stale chat token used to sign
    //    the user out of the entire app.
    if (sentToken == null) {
      final sentHeader = options.headers['Authorization']?.toString();
      if (sentHeader != null) {
        Utils.debugLog(
          'AuthInterceptor: 401 on ${options.method} ${options.path} '
          '— not the session token, session kept',
        );
        // A chat-token 401 is recoverable: drop the cached JWT so the next
        // chat call mints a fresh one instead of replaying a dead token.
        _invalidateChatTokenIfUsed(sentHeader);
      }
      handler.next(err);
      return;
    }

    // Already replayed once with a token minted seconds ago, and refused
    // again. The session is demonstrably alive — the renewal that produced
    // that token proved it — so this 401 is the endpoint's answer, not the
    // session's. Hand it to the caller rather than signing anyone out over
    // it, and never renew a second time for the same request.
    if (options.extra[_replayedKey] == true) {
      Utils.debugLog(
        'AuthInterceptor: ${options.method} ${options.path} still 401 after '
        'renewal — surfacing to caller, session kept',
      );
      handler.next(err);
      return;
    }

    // The backend distinguishes the two reasons a request is unauthorized.
    // `unauthorized` is a genuine refusal rather than an expiry, so renewing
    // would only mint a token this endpoint refuses in exactly the same way.
    //
    // It still isn't grounds for a logout while the session can renew: the
    // only 401 that proves a session is over is the one the *refresh*
    // endpoint returns. A learner whose account is genuinely gone reaches
    // that verdict on their own — the access token expires, renewal is
    // refused, and they are signed out then. Until that happens they see
    // this endpoint's error, which is the truthful thing to show them.
    //
    // Without a refresh token there is nothing to wait for, and this is the
    // terminal 401 it always was.
    final code = TokenRefreshService.errorCodeOf(err.response?.data);
    if (code == 'unauthorized') {
      if (sl<SessionService>().canRenewSession) {
        Utils.debugLog(
          'AuthInterceptor: 401 code=unauthorized on ${options.method} '
          '${options.path} — a refusal, not an expiry; session kept',
        );
      } else {
        _forceLogout(
          '401 code=unauthorized on ${options.method} ${options.path} with no '
          'refresh token',
        );
      }
      handler.next(err);
      return;
    }

    // `token_expired`, or an older deployment that sends no code at all.
    // A session with nothing to renew with resolves to a logout inside
    // [TokenRefreshService.renew], which is the second and last case that
    // ends a session.
    //
    // Deliberately not awaited — [onError] is synchronous and the handler
    // is allowed to be called later. [_renewAndReplay] owns its own error
    // handling precisely because nothing here can catch what it throws.
    _renewAndReplay(err, sentToken, handler);
  }

  /// Renew the access token (single-flight, shared with every other request
  /// that 401'd at the same moment) and replay [err]'s request with it.
  ///
  /// Every path out of this method completes [handler] exactly once. That is
  /// the whole contract: [onError] has already returned by the time this
  /// runs, so an escape route that leaves the handler untouched doesn't
  /// surface as an error — it leaves the caller's future pending forever,
  /// which reads to the learner as a screen that never finishes loading.
  Future<void> _renewAndReplay(
    DioException err,
    String sentToken,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final options = err.requestOptions;
      final current = _getToken();

      if (current == null || current.isEmpty) {
        // A logout raced this request. Nothing to renew, nothing to replay.
        _forward(handler, err);
        return;
      }

      if (current != sentToken) {
        // Somebody else already renewed while this was in flight, so its 401
        // is stale news about a token that no longer exists. Replay on the
        // current one instead of renewing again — a second renewal would
        // rotate a perfectly good refresh token for nothing, and rotation is
        // exactly what reuse detection watches.
        Utils.debugLog(
          'AuthInterceptor: token already renewed elsewhere — replaying '
          '${options.method} ${options.path}',
        );
        await _replayOrForward(err, current, handler);
        return;
      }

      final result = await sl<TokenRefreshService>().renew();

      if (result.isRenewed) {
        await _replayOrForward(err, result.accessToken!, handler);
        return;
      }

      if (result.outcome == TokenRenewal.sessionDead) {
        _forceLogout('renewal refused (${result.detail})');
        _forward(handler, err);
        return;
      }

      // Transient: no signal, a timeout, a 5xx, a body we couldn't read.
      // That is not evidence of anything about the session, so it keeps its
      // tokens and the caller sees the original 401. The next call retries.
      Utils.debugLog(
        'AuthInterceptor: renewal unavailable (${result.detail}) — session '
        'kept, 401 surfaced to caller',
      );
      _forward(handler, err);
    } catch (e) {
      // A hung request is worse than a failed one. Whatever went wrong —
      // a service not registered yet, a throw from deep inside the renewal
      // — the caller still gets its answer.
      Utils.debugLog('AuthInterceptor: renew/replay path threw — $e');
      _forward(handler, err);
    }
  }

  /// Re-issue the failed request carrying [accessToken]. Falls back to
  /// surfacing an error whenever the request can't be rebuilt or the retry
  /// itself fails.
  Future<void> _replayOrForward(
    DioException err,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    final RequestOptions replayed;
    try {
      replayed = _rebuild(options, accessToken);
    } catch (e) {
      // A body that can't be re-sent (a consumed stream, a form whose parts
      // won't clone). The session is renewed either way, so the next attempt
      // from the UI succeeds — only this one call is lost.
      Utils.debugLog(
        'AuthInterceptor: ${options.method} ${options.path} not replayable '
        '— $e',
      );
      _forward(handler, err);
      return;
    }

    final Response<dynamic> response;
    try {
      response = await sl<Dio>().fetch<dynamic>(replayed);
    } on DioException catch (retryError) {
      _forward(handler, retryError);
      return;
    } catch (e) {
      Utils.debugLog('AuthInterceptor: replay threw — $e');
      _forward(handler, err);
      return;
    }

    // Outside the try on purpose. Wrapping this would put a second
    // completion (the catch's `next`) on the failure path of the first one.
    handler.resolve(response);
  }

  /// Hand [err] to the caller, tolerating an already-completed handler.
  ///
  /// Completing an [ErrorInterceptorHandler] twice throws. Routing every
  /// async exit through here is what lets the recovery in
  /// [_renewAndReplay]'s catch block run unconditionally without turning a
  /// handled error into an unhandled one.
  void _forward(ErrorInterceptorHandler handler, DioException err) {
    try {
      handler.next(err);
    } catch (e) {
      Utils.debugLog('AuthInterceptor: handler already completed — $e');
    }
  }

  /// A copy of [options] carrying [accessToken] and marked as replayed.
  ///
  /// `FormData` is cloned rather than reused: the original was consumed
  /// producing the request that just 401'd, and sending it again would
  /// stream an exhausted body.
  RequestOptions _rebuild(RequestOptions options, String accessToken) {
    final data = options.data;
    return options.copyWith(
      data: data is FormData ? data.clone() : data,
      headers: <String, dynamic>{
        ...options.headers,
        'Authorization': 'Bearer $accessToken',
      },
      extra: <String, dynamic>{
        ...options.extra,
        _sentTokenKey: accessToken,
        _replayedKey: true,
      },
    );
  }

  /// Clears the cached chat JWT when [sentHeader] is the one that just got
  /// rejected. Guarded on equality so a 401 from some unrelated bearer
  /// can't wipe a chat token that is still good.
  void _invalidateChatTokenIfUsed(String sentHeader) {
    final session = sl<SessionService>();
    final chatToken = session.chatToken;
    if (chatToken == null || chatToken.isEmpty) return;
    if (sentHeader != 'Bearer $chatToken') return;
    Utils.debugLog('AuthInterceptor: dropping stale chat token for re-mint');
    session.clearChatToken();
  }

  /// End the session for real. Guarded so a screenful of parallel 401s
  /// produces one logout, not five.
  void _forceLogout(String reason) {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    Utils.debugLog('AuthInterceptor: $reason — logging out');
    // Fire-and-forget: do not block the error handler chain. The caller
    // still sees the 401, and the logout navigation happens on the next
    // microtask.
    _logoutAndRedirect();
  }

  Future<void> _logoutAndRedirect() async {
    try {
      // No `revokeSession` here on purpose: we only reach this path because
      // the backend already refused the refresh token (or there was never
      // one), so there is nothing left to revoke.
      await sl<SessionService>().clearToken();
      OrgCodeService.instance.clear();
      // Use go() to swap the stack rather than push() so the user can't
      // back-navigate into the now-unauthenticated app.
      if (dotenv.env['ORG_ID'] == 'CRINZA') {
        AppRouter.router.go(AppRoutes.orgCode);
      } else {
        AppRouter.router.go(AppRoutes.login);
      }
    } catch (e) {
      Utils.debugLog('AuthInterceptor: logout redirect failed — $e');
    } finally {
      _logoutInProgress = false;
    }
  }

  /// Retrieve the access token from SessionService.
  String? _getToken() => sl<SessionService>().token;
}
