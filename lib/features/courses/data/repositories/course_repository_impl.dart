import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;

  CourseRepositoryImpl(this._apiClient);



  @override
  Future<Either<Failure, Course>> getCourseDetail(int courseId) async {
    try {
      final json = await _apiClient.getCourseDetail(courseId);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Invalid course payload',
          ),
        );
      }
      return Right(Course.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }



  @override
  Future<Either<Failure, List<CourseReview>>> getCourseReviews(
    int courseId,
  ) async {
    try {
      final json = await _apiClient.getCourseReviews(courseId);
      return Right(_parseReviewList(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CourseReview>>> saveCourseReview({
    required int courseId,
    required double rating,
    required String reviewMessage,
  }) async {
    try {
      final json = await _apiClient.saveCourseReview({
        'courseId': courseId,
        'rating': rating,
        'reviewMessage': reviewMessage,
      });
      return Right(_parseReviewList(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> saveContinueCourse({
    required int courseId,
    required bool isPurchased,
  }) async {
    try {
      final json = await _apiClient.saveContinueCourse({
        'courseId': courseId,
        'isPurchased': isPurchased,
      });
      final data = json['data'];
      // API returns `data: true` on success.
      return Right(data is bool ? data : true);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CourseSummary>>> getContinueCourses() async {
    try {
      final json = await _apiClient.getContinueCourses();
      return Right(_parseCourseSummaryList(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CourseSummary>>> getMyCourses() async {
    try {
      final json = await _apiClient.getMyCourses();
      return Right(_parseCourseSummaryList(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> rewatchCourse(int purchasedId) async {
    try {
      final json = await _apiClient.rewatchCourse(purchasedId);
      // API returns `{success, message, data: true}` — fall back to the
      // top-level `success` if `data` isn't a bool.
      final data = json['data'];
      final ok = data is bool ? data : (json['success'] as bool? ?? true);
      return Right(ok);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> recordContentCompletion({
    required int coursePurchasedId,
    required String jsonContentId,
  }) async {
    try {
      // Two valid outcomes from the API and we don't act differently on
      // either:
      //   {success: true,  data: true}  → just recorded
      //   {success: false, data: false, message: "Course completion already
      //                                            reached."} → already done
      // Both mean the user has cleared the bar; the caller caches the key
      // and stops calling. Throwing DioExceptions still surface as Lefts.
      await _apiClient.recordContentCompletion({
        'coursePurchasedId': coursePurchasedId,
        'jsonContentId': jsonContentId,
      });
      return const Right(true);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }



  @override
  Future<Either<Failure, LivePlayback>> getLiveClassPlayback(
    String roomId,
  ) async {
    try {
      final json = await _apiClient.getLiveClassPlayback(roomId);
      final data = json['data'];
      final hlsUrl = data is Map<String, dynamic>
          ? data['hlsUrl']?.toString()
          : null;
      if (hlsUrl == null || hlsUrl.isEmpty) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Invalid playback payload',
          ),
        );
      }
      // Prefer an explicit server `audioUrl`; else derive it.
      final audioUrl = data is Map<String, dynamic>
          ? data['audioUrl']?.toString()
          : null;
      return Right(LivePlayback.fromData(hlsUrl, audioUrl: audioUrl));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getStreamToken() async {
    try {
      final json = await _apiClient.getStreamToken();
      final data = json['data'];
      final token = data is Map<String, dynamic>
          ? data['token']?.toString()
          : null;
      if (token == null || token.isEmpty) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Invalid token payload',
          ),
        );
      }
      return Right(token);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LiveChatMessage>>> getLiveClassChat(
    String roomId, {
    int? beforeId,
    int? limit,
  }) async {
    try {
      final json = await _apiClient.getLiveClassChat(roomId, beforeId, limit);
      // Raw log so a shape mismatch (where the messages actually live in
      // the envelope) is obvious when history comes back empty.
      // ignore: avoid_print
      print('[ClassChat] history raw=$json');
      final data = json['data'];
      // Tolerate a bare list, the envelope's `data` being the list, or a
      // list nested under a variety of keys.
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        final nested = data['items'] ??
            data['messages'] ??
            data['chats'] ??
            data['history'] ??
            data['data'] ??
            data['results'] ??
            data['records'];
        list = nested is List ? nested : const [];
      } else if (json['messages'] is List) {
        list = json['messages'] as List;
      } else {
        list = const [];
      }
      final messages = list
          .whereType<Map<String, dynamic>>()
          .map(LiveChatMessage.fromJson)
          .toList();
      return Right(messages);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CoursePricing>> getCoursePricing(
    int courseId, {
    required int priceId,
    String? couponCode,
  }) async {
    try {
      final json = await _apiClient.getCoursePricing(courseId, priceId, couponCode);
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(
          Failure.server(
            message: json['message']?.toString() ?? 'Invalid pricing payload',
          ),
        );
      }
      return Right(CoursePricing.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CourseFilterData>> getCourseCategories() async {
    try {
      final json = await _apiClient.getCourseCategories();
      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        return Left(
          Failure.server(
            message:
                json['message']?.toString() ?? 'Invalid categories payload',
          ),
        );
      }
      return Right(CourseFilterData.fromJson(data));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CourseCatalogResponse>> getCatalog({
    int? pageNo,
    String? searchQuery,
    String? courseType,
    int? categoryId,
    int? tileId,
    int? courseStatusType,
    CatalogSortBy? sortBy,
  }) async {
    try {
      final json = await _apiClient.getCourseCatalog(
        pageNo: pageNo,
        searchQuery: searchQuery,
        courseType: courseType,
        categoryId: categoryId,
        tileId: tileId,
        courseStatusType: courseStatusType,
        sortBy: sortBy?.apiValue,
      );
      return Right(CourseCatalogResponse.fromJson(json));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  List<CourseSummary> _parseCourseSummaryList(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CourseSummary.fromJson)
        .toList();
  }

  List<CourseReview> _parseReviewList(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CourseReview.fromJson)
        .toList();
  }
}
