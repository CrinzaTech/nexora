import 'package:dio/dio.dart';
import 'package:nexora/core/error/failures.dart';

/// Converts a [DioException] into the app's [Failure] sealed type.
Failure mapDioExceptionToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return Failure.network(
        message: 'Connection timed out. Check your internet connection.',
      );
    case DioExceptionType.connectionError:
      return Failure.network(
        message: 'No internet connection.',
      );
    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final message = _extractServerMessage(e.response) ??
          'Server error (${statusCode ?? 'unknown'})';
      return Failure.server(message: message, statusCode: statusCode);
    case DioExceptionType.cancel:
      return Failure.unknown(message: 'Request was cancelled.');
    case DioExceptionType.badCertificate:
      return Failure.network(message: 'SSL certificate error.');
    case DioExceptionType.unknown:
      return Failure.unknown(message: e.message ?? 'An unknown error occurred.');
  }
}

/// Pulls a user-readable error string off the response body when the
/// backend ships one. The API is not consistent about casing —
/// `Message` (PascalCase) on auth + assignment endpoints, `message`
/// (camelCase) on courses / payments — so the lookup walks several
/// known shapes and returns the first non-empty hit. Falls through
/// to `null` so the caller's "Server error (N)" default takes over.
String? _extractServerMessage(Response? response) {
  try {
    final data = response?.data;
    if (data is! Map) return null;
    const candidateKeys = [
      'message',
      'Message',
      'error',
      'Error',
      'errorMessage',
      'ErrorMessage',
      'detail',
      'Detail',
    ];
    for (final key in candidateKeys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }

    // ASP.NET `ProblemDetails`, raised by `[ApiController]` before the
    // handler runs — a missing or malformed field. It carries no
    // `message` at all, so without this a "Phone number is required."
    // reaches the user as "Server error (400)".
    //
    // The field errors are preferred over `title`, which is always the
    // generic "One or more validation errors occurred."
    final errors = data['errors'] ?? data['Errors'];
    if (errors is Map) {
      for (final entry in errors.values) {
        if (entry is List) {
          for (final line in entry) {
            if (line is String && line.trim().isNotEmpty) return line;
          }
        } else if (entry is String && entry.trim().isNotEmpty) {
          return entry;
        }
      }
    }

    final title = data['title'] ?? data['Title'];
    if (title is String && title.trim().isNotEmpty) return title;
  } catch (_) {}
  return null;
}
