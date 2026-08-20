import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_interceptor.dart';

/// Creates and configures the singleton [Dio] instance.
///
/// Called once from [setupLocator]; do not instantiate directly.
Dio createDioClient() {
  final baseUrl = dotenv.env['BASE_URL'] ?? '';

  assert(baseUrl.isNotEmpty, 'BASE_URL is missing from .env');

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Auth token injection
  dio.interceptors.add(AuthInterceptor());

  // Pretty-print logs in debug builds only
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  return dio;
}
