import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_interceptor.dart';

/// The transport settings every client in the app shares.
BaseOptions _baseOptions() {
  final baseUrl = dotenv.env['BASE_URL'] ?? '';

  assert(baseUrl.isNotEmpty, 'BASE_URL is missing from .env');

  return BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
}

/// Attaches the pretty-printing logger, debug builds only.
void _addDebugLogging(Dio dio) {
  if (!kDebugMode) return;
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (o) => debugPrint(o.toString()),
    ),
  );
}

/// Creates and configures the singleton [Dio] instance.
///
/// Called once from [setupLocator]; do not instantiate directly.
Dio createDioClient() {
  final dio = Dio(_baseOptions());

  // Auth token injection + 401 renewal/replay.
  dio.interceptors.add(AuthInterceptor());

  _addDebugLogging(dio);

  return dio;
}

/// A client with **no [AuthInterceptor]**, for the two endpoints that must
/// not go through it: `refresh-token` and `logout`.
///
/// Both are unauthenticated by design, and both are called from inside the
/// 401 path. Sending them through the shared client would mean a failing
/// renewal triggers the very interceptor that asked for the renewal —
/// infinite recursion in the exact situation the flow exists to survive.
///
/// It also keeps the refresh token out of `onRequest`'s reach: nothing here
/// can accidentally stamp a `Bearer` header onto a call whose whole point
/// is that the access token is dead.
Dio createBareDioClient() {
  final dio = Dio(_baseOptions());
  _addDebugLogging(dio);
  return dio;
}
