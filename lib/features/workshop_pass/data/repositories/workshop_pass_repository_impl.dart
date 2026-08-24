import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/api_endpoints.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/workshop_pass/data/models/my_webinar_model.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/data/services/workshop_pass_cache.dart';
import 'package:nexora/features/workshop_pass/domain/repositories/workshop_pass_repository.dart';

/// Takes raw [Dio] alongside [ApiClient] for the same reason the
/// certificate repository does: the download returns a PDF, which needs
/// `ResponseType.bytes` and a much longer receive timeout than the
/// generated client can express.
class WorkshopPassRepositoryImpl implements WorkshopPassRepository {
  final ApiClient _apiClient;
  final Dio _dio;
  final WorkshopPassCache _cache;

  WorkshopPassRepositoryImpl(this._apiClient, this._dio, this._cache);

  @override
  Future<Either<Failure, MyWebinarPage>> getMyWebinars({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    try {
      final json = await _apiClient.getMyWebinars(pageNo, pageSize);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        // An empty history still arrives as a well-formed 200, so a
        // missing `data` is a genuine fault rather than "nothing booked".
        return Left(Failure.server(message: 'Could not read your bookings.'));
      }
      return Right(MyWebinarPage.fromJson(data));
    } on DioException catch (e) {
      // The mapper already reads both `message` and `Message`: this API
      // serialises handled responses in camelCase and unhandled ones
      // through middleware that emits PascalCase verbatim, and the
      // unhandled case is exactly when the message matters most.
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<WorkshopPass?> cachedPass(String slug) => _cache.read(slug);

  @override
  Future<Either<Failure, WorkshopPass>> getPass(String slug) async {
    if (slug.trim().isEmpty) {
      // The endpoint 400s on this, and an empty slug can only be a
      // client bug — no point spending a round trip to be told so.
      return Left(
        Failure.server(message: 'This workshop link is not valid.', statusCode: 400),
      );
    }

    try {
      final json = await _apiClient.getWorkshopPass(slug);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(
          Failure.server(message: 'The pass came back empty. Please try again.'),
        );
      }

      final pass = WorkshopPass.fromJson(data);
      // Cached on every success, not only the first: the artwork is
      // rebuilt server-side each time, so an organiser who restyles
      // their pass improves the copy an attendee already holds.
      await _cache.write(slug, pass);
      return Right(pass);
    } on DioException catch (e) {
      // No decoding dance here — this endpoint answers JSON on every
      // path, so `mapDioExceptionToFailure` reads the attendee-facing
      // `message` straight off the body and keeps the status with it.
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DownloadedPass>> downloadPass({
    required String slug,
    required WorkshopPass pass,
  }) async {
    // Built from the slug against our own `baseUrl`, **not** from the
    // absolute `downloadUrl` the payload carries.
    //
    // The API doc says to prefer `downloadUrl`, and that was the original
    // reading — but a server-built absolute URL is the one variable that
    // separates this call from the fetch beside it, and from every other
    // download in this app (the certificate goes through a relative path
    // and works). An absolute URL is whatever the server composed: a
    // different host or scheme behind nginx, a stale hardcoded origin, or
    // a redirect — and any of those reaches somewhere our session was
    // never established, which answers 401 and logs the attendee out.
    //
    // The relative form cannot drift: same origin as every other
    // authenticated call, same interceptor path, no redirect to follow.
    // `downloadUrl` stays as the fallback for a payload with no slug to
    // work from.
    final slugPath = slug.trim().isEmpty
        ? null
        : ApiEndpoints.workshopPassDownload.replaceFirst(
            '{slug}',
            Uri.encodeComponent(slug.trim()),
          );
    final url = slugPath ?? pass.downloadUrl.trim();

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          // The endpoint returns a PDF — Dio's default JSON parsing
          // would mangle the bytes into a broken string.
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
          // A cold start launches Chromium server-side and takes 2–5s;
          // the Dio default of 30s occasionally clips it. Deliberately
          // *not* applied to `getPass`, which launches no browser and
          // answers in a few hundred milliseconds.
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return Left(
          Failure.server(
            message: 'The pass came back empty. Please try again.',
            statusCode: response.statusCode,
          ),
        );
      }

      final passNo = response.headers.value('x-pass-no')?.trim().isNotEmpty ==
              true
          ? response.headers.value('x-pass-no')!.trim()
          : pass.passNo;
      final filename =
          _extractFilename(response.headers.value('content-disposition')) ??
          '${passNo.isEmpty ? 'workshop-pass' : passNo}.pdf';

      // Documents, not cache: the OS clears caches whenever it likes and
      // an attendee expects a saved ticket to still be there on the day.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_sanitize(filename)}');
      await file.writeAsBytes(bytes, flush: true);

      return Right(
        DownloadedPass(
          path: file.path,
          passNo: passNo,
          workshopTitle: pass.workshopTitle,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(_decodeErrorBody(e)));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// The bytes/JSON trap: `ResponseType.bytes` is required for the PDF,
  /// which means a 402/409 body arrives as bytes too. Without decoding
  /// it back into a Map the mapper can't read `message`, and the
  /// attendee is shown `Instance of '_Uint8List'` instead of the reason.
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
    final safe = flat.isEmpty ? 'workshop-pass' : flat;
    return safe.toLowerCase().endsWith('.pdf') ? safe : '$safe.pdf';
  }
}
