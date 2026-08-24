import 'package:dio/dio.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_router.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Injects the Bearer token into every outgoing request and centralizes
/// 401 handling: a request that came back unauthorized **while carrying the
/// current main session token** triggers a global logout (clear token +
/// return to /login). Every other 401 — unauthenticated endpoints, chat-token
/// calls, requests that outlived the token they were sent with — is passed
/// through to the caller with the session left alone.
///
/// Token source: [SessionService] — an in-memory cache hydrated from secure
/// storage (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on
/// Android) during app startup.
class AuthInterceptor extends Interceptor {
  /// Re-entry guard: if a screen fires several requests in parallel they may
  /// all come back with 401 once the token expires. Without this flag we'd
  /// stack multiple `router.go(login)` calls and clearToken() races.
  static bool _logoutInProgress = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Respect an Authorization header that the caller already set — this
    // is how chat-feature endpoints pass the dedicated chat JWT instead
    // of the main access token. Without this guard the interceptor
    // would unconditionally clobber the chat token with the main one.
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    final token = _getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// The workshop-pass family, exempt from the global logout below.
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
  /// answers 401 and logs them out properly. This only declines to infer
  /// a dead session from the one endpoint least qualified to report it.
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

    final sentHeader = err.requestOptions.headers['Authorization']?.toString();
    final sessionToken = _getToken();

    // Only a 401 on a request that carried the *current main session token*
    // means the session is dead.
    //
    //  • No Authorization header at all → /send-otp, /verify-otp and friends.
    //    That's a credential failure, not session expiry.
    //  • A different Bearer → a chat-token call (chat endpoints set the
    //    header explicitly). Those JWTs expire on their own schedule; killing
    //    the whole session over one is how a stale chat token used to sign
    //    the user out of the entire app.
    //  • A Bearer that no longer matches → a request that was already in
    //    flight when the token was replaced. Its 401 is stale news.
    final usedSessionToken =
        sentHeader != null &&
        sessionToken != null &&
        sessionToken.isNotEmpty &&
        sentHeader == 'Bearer $sessionToken';

    if (!usedSessionToken) {
      if (sentHeader != null) {
        Utils.debugLog(
          'AuthInterceptor: 401 on '
          '${err.requestOptions.method} ${err.requestOptions.path} '
          '— not the session token, session kept',
        );
        // A chat-token 401 is recoverable: drop the cached JWT so the next
        // chat call mints a fresh one instead of replaying a dead token.
        _invalidateChatTokenIfUsed(sentHeader);
      }
      handler.next(err);
      return;
    }

    if (!_logoutInProgress) {
      _logoutInProgress = true;
      Utils.debugLog(
        'AuthInterceptor: 401 on '
        '${err.requestOptions.method} ${err.requestOptions.path} '
        '— session token rejected, logging out',
      );
      // Fire-and-forget: do not block the error handler chain. The caller
      // still sees the 401 (we call handler.next below), and the logout
      // navigation happens on the next microtask.
      _logoutAndRedirect();
    }

    handler.next(err);
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

  Future<void> _logoutAndRedirect() async {
    try {
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
