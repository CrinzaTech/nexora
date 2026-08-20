import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';

/// Single owner of the dedicated **chat JWT** — the token used as the
/// bearer for every chat REST call (group *and* direct) and for the
/// SignalR hub handshake.
///
/// Extracted out of `ChatGroupRepositoryImpl` when personal chat landed:
/// both chat repositories need the exact same lazy-mint behaviour, and
/// duplicating it meant two places to fix whenever token handling
/// changes. `ChatGroupRepositoryImpl.generateChatToken()` is now a thin
/// pass-through to [generateToken] so its public contract is unchanged.
class ChatTokenProvider {
  final ApiClient _apiClient;
  final SessionService _session;

  ChatTokenProvider(this._apiClient, this._session);

  /// Mint a fresh chat token and cache it on [SessionService]. Callers
  /// normally want [ensureBearer] instead — this bypasses the cache.
  Future<Either<Failure, String>> generateToken({String? name}) async {
    try {
      // The `name` segment is required by the backend. Resolve a
      // non-empty value (caller-supplied → profile.name → fallback) so
      // the URL never ends up with an empty one (which 404s).
      final resolvedName = _resolveStudentName(name);
      final json = await _apiClient.generateChatToken(resolvedName);
      // Backend ships the token as `data: "<jwt>"`. Be defensive about
      // wrappers in case the contract drifts.
      final raw = json['data'];
      final token = raw is String
          ? raw
          : (raw is Map<String, dynamic> ? raw['token']?.toString() : null);
      if (token == null || token.isEmpty) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Failed to mint chat token',
          ),
        );
      }
      await _session.saveChatToken(token);
      return Right(token);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// The `Authorization` header value every chat REST call needs.
  /// Mints + caches a fresh token when the session doesn't have one, so
  /// callers never have to bootstrap it explicitly.
  Future<Either<Failure, String>> ensureBearer() async {
    final cached = _session.chatToken;
    if (cached != null && cached.isNotEmpty) {
      return Right('Bearer $cached');
    }
    final minted = await generateToken();
    return minted.map((token) => 'Bearer $token');
  }

  /// Picks the name written into the `?name=` query param. Preference
  /// order:
  ///   1. an explicit argument the caller passed in (e.g. a future
  ///      "log in with a different display name" flow)
  ///   2. the cached profile's `name`, pulled from the singleton
  ///      [ProfileCubit]
  ///   3. the literal string `Student` as a last-resort fallback so the
  ///      request still carries a non-empty name — better than a 404.
  String _resolveStudentName(String? explicit) {
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final profile = sl<ProfileCubit>().state.maybeWhen(
      loaded: (p) => p,
      updated: (p) => p,
      updating: (p) => p,
      orElse: () => null,
    );
    final fromProfile = profile?.name?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return 'Student';
  }
}
