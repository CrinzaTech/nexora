import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Base failure class for error handling
@freezed
class Failure with _$Failure {
  const factory Failure.server({
    required String message,
    int? statusCode,
  }) = ServerFailure;

  const factory Failure.network({
    required String message,
  }) = NetworkFailure;

  const factory Failure.cache({
    required String message,
  }) = CacheFailure;

  const factory Failure.unknown({
    required String message,
  }) = UnknownFailure;

  /// The live-session playback endpoint said "no media for you right
  /// now" (410) and named why: `Ended`, `Cancelled`, `Paused`,
  /// `Scheduled`, `Ready`, `Live`, or a value added later. Distinct from
  /// [Failure.server] so callers can pick the ended screen for the two
  /// terminal statuses and the waiting screen — with the server's own
  /// [message] — for every other. [message] may be empty.
  const factory Failure.sessionStatus({
    required String message,
    required String status,
  }) = SessionStatusFailure;
}
