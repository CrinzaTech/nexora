import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/data/services/free_course_registry.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;
  final FreeCourseRegistry _freeCourseRegistry;

  CourseRepositoryImpl(this._apiClient, this._freeCourseRegistry);



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
      final withStatus = liveSessionStatusFailure(e);
      if (withStatus != null) return Left(withStatus);
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
  Future<Either<Failure, List<LivePoll>>> getLiveClassPolls(
    String roomId,
  ) async {
    try {
      final json = await _apiClient.getLiveClassPolls(roomId);
      final data = json['data'];
      final raw = data is Map
          ? (data['polls'] ?? data['items'] ?? data['data'])
          : data;
      final polls = <LivePoll>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            polls.add(LivePoll.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return Right(polls);
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
      final normalisedType = courseType?.toLowerCase().trim();
      // The catalog rows carry no price or free-marker, so the free ids
      // are resolved alongside the page rather than after it — the two
      // requests overlap instead of stacking their latency. Skipped when
      // the caller already filtered to free courses (every row is free)
      // or to paid ones (no row is).
      final freeIdsFuture = normalisedType == null
          ? _freeCourseRegistry.freeCourseIds()
          : Future.value(const <int>{});
      final json = await _apiClient.getCourseCatalog(
        pageNo: pageNo,
        searchQuery: searchQuery,
        courseType: courseType,
        categoryId: categoryId,
        tileId: tileId,
        courseStatusType: courseStatusType,
        sortBy: sortBy?.apiValue,
      );
      final response = CourseCatalogResponse.fromJson(json);
      // Once the backend ships `isCourseFree` on catalog rows, every
      // row answers for itself and the id lookup is pure waste — so the
      // first page that comes back fully marked switches it off for the
      // rest of the session.
      if (response.courses.isNotEmpty &&
          response.courses.every((c) => c.hasServerFreeFlag)) {
        _freeCourseRegistry.markServerAuthoritative();
      }
      final freeIds = await freeIdsFuture;
      return Right(
        _withFreeFlags(
          response,
          allFree: normalisedType == 'free',
          freeIds: freeIds,
        ),
      );
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Stamps `isCourseFree` onto rows the catalog payload left unmarked.
  ///
  /// A row that carried its own marker is returned untouched — free or
  /// paid, the server's answer stands. Only rows with no marker at all
  /// ([CourseSummary.hasServerFreeFlag] `false`) are filled in, from
  /// the `courseType=free` filter the caller used or from the id set
  /// [FreeCourseRegistry] resolved.
  CourseCatalogResponse _withFreeFlags(
    CourseCatalogResponse response, {
    required bool allFree,
    required Set<int> freeIds,
  }) {
    if (!allFree && freeIds.isEmpty) return response;
    return CourseCatalogResponse(
      courses: response.courses.map((c) {
        if (c.hasServerFreeFlag) return c;
        if (!allFree && !freeIds.contains(c.courseId)) return c;
        return c.copyWith(isCourseFree: true, hasServerFreeFlag: true);
      }).toList(),
      totalCount: response.totalCount,
      pageNo: response.pageNo,
      totalPages: response.totalPages,
    );
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
