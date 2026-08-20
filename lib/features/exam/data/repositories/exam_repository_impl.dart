import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

class ExamRepositoryImpl implements ExamRepository {
  final ApiClient _apiClient;

  ExamRepositoryImpl(this._apiClient);

  /// Unwraps the `{ success, message, data }` envelope. Returns the `data`
  /// map on success, or a [Failure] otherwise. `data` that isn't a map
  /// (e.g. a list, for history) is handled by the caller via [_dataList].
  Either<Failure, Map<String, dynamic>> _data(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return Left(
        Failure.server(message: json['message']?.toString() ?? 'Request failed'),
      );
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) return Right(data);
    return Left(
      Failure.server(message: json['message']?.toString() ?? 'No data returned'),
    );
  }

  @override
  Future<Either<Failure, String>> resolvePhoneNumber() async {
    try {
      final json = await _apiClient.getUserProfile();
      final data = json['data'];
      final phone = (data is Map<String, dynamic>)
          ? data['phoneNumber']?.toString()
          : null;
      if (phone == null || phone.trim().isEmpty) {
        return const Left(
          Failure.server(message: 'Could not resolve your phone number.'),
        );
      }
      return Right(phone.trim());
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AttemptStateResponse>> getGate({
    required int examId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.getExamGate(examId, phoneNumber);
      return _data(json).map(AttemptStateResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AttemptStateResponse>> start({
    required int examId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.startExam(examId, {
        'phoneNumber': phoneNumber,
      });
      return _data(json).map(AttemptStateResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamPaperResponse>> getPaper({
    required int attemptId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.getExamPaper(attemptId, phoneNumber);
      return _data(json).map(ExamPaperResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompetitiveQuestionResponse>> getQuestion({
    required int attemptId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.getExamQuestion(attemptId, phoneNumber);
      return _data(json).map(CompetitiveQuestionResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompetitiveAnswerResultResponse>> answerQuestion({
    required int attemptId,
    required String phoneNumber,
    required Map<String, dynamic> answer,
  }) async {
    try {
      final json = await _apiClient.answerExamQuestion(attemptId, {
        'phoneNumber': phoneNumber,
        'answer': answer,
      });
      return _data(json).map(CompetitiveAnswerResultResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SaveProgressResponse>> saveProgress({
    required int attemptId,
    required String phoneNumber,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final json = await _apiClient.saveExamProgress(attemptId, {
        'phoneNumber': phoneNumber,
        'answers': answers,
      });
      // The save endpoint returns `{ ok, message }` inside `data`.
      return _data(json).map(SaveProgressResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamResultResponse>> submit({
    required int attemptId,
    required String phoneNumber,
    required bool autoSubmitted,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final json = await _apiClient.submitExam(attemptId, {
        'phoneNumber': phoneNumber,
        'autoSubmitted': autoSubmitted,
        'answers': answers,
      });
      return _data(json).map(ExamResultResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamResultResponse>> getResult({
    required int attemptId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.getExamResult(attemptId, phoneNumber);
      return _data(json).map(ExamResultResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AttemptHistoryItem>>> getHistory({
    required int examId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.getExamHistory(examId, phoneNumber);
      if (json['success'] == false) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Request failed',
          ),
        );
      }
      final data = json['data'];
      final list = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(AttemptHistoryItem.fromJson)
              .toList(growable: false)
          : <AttemptHistoryItem>[];
      return Right(list);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AttemptStateResponse>> reattempt({
    required int examId,
    required String phoneNumber,
  }) async {
    try {
      final json = await _apiClient.reattemptExam(examId, {
        'phoneNumber': phoneNumber,
      });
      return _data(json).map(AttemptStateResponse.fromJson);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
