import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/domain/repositories/certificate_repository.dart';

class CertificateRepositoryImpl implements CertificateRepository {
  final ApiClient _apiClient;
  final Dio _dio;

  CertificateRepositoryImpl(this._apiClient, this._dio);

  @override
  Future<Either<Failure, List<CompletedCourse>>> getCompletedCourses() async {
    try {
      final json = await _apiClient.getCompletedCertificateCourses();
      final data = json['data'] as List<dynamic>? ?? const [];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(CompletedCourse.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DownloadedCertificate>> downloadCertificate({
    required int courseId,
    required String courseName,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        ApiEndpoints.certificateDownload.replaceFirst(
          '{courseId}',
          '$courseId',
        ),
        options: Options(
          // The endpoint returns a PDF — Dio's default JSON parsing
          // would mangle the bytes into a broken string.
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
          // The first download after an API restart launches Chromium
          // server-side and can take 2–5s; the Dio default of 30s
          // occasionally clips a cold start.
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return Left(
          Failure.server(
            message: 'The certificate came back empty. Please try again.',
            statusCode: response.statusCode,
          ),
        );
      }

      final certificateNo =
          response.headers.value('x-certificate-no')?.trim() ?? '';
      final filename =
          _extractFilename(response.headers.value('content-disposition')) ??
          '${certificateNo.isEmpty ? 'certificate_$courseId' : certificateNo}.pdf';

      // Documents, not cache: the OS clears caches whenever it likes and
      // a learner reasonably expects a saved certificate to persist.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_sanitize(filename)}');
      await file.writeAsBytes(bytes, flush: true);

      return Right(
        DownloadedCertificate(
          path: file.path,
          certificateNo: certificateNo,
          courseName: courseName,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(_decodeErrorBody(e)));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// The bytes/JSON trap: `ResponseType.bytes` is required for the PDF,
  /// which means the 404/409 bodies arrive as bytes too. Without decoding
  /// them back into a Map, `mapDioExceptionToFailure` can't read
  /// `message` and every refusal would show the generic
  /// "Server error (409)" instead of the sentence written for learners.
  DioException _decodeErrorBody(DioException e) {
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        e.response!.data = jsonDecode(utf8.decode(data));
      } catch (_) {
        // Not JSON — leave it; the mapper falls back to its default.
      }
    }
    return e;
  }

  /// Pulls the filename out of `Content-Disposition: attachment; filename=...`.
  String? _extractFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1)?.trim();
  }

  /// The filename comes from a server header, so it can't be trusted to
  /// stay inside the documents directory — strip anything that would let
  /// it traverse out, and keep it a `.pdf`.
  String _sanitize(String filename) {
    final flat = filename
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll('..', '_')
        .trim();
    final safe = flat.isEmpty ? 'certificate' : flat;
    return safe.toLowerCase().endsWith('.pdf') ? safe : '$safe.pdf';
  }
}
