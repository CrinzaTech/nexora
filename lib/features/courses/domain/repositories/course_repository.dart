import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';

abstract class CourseRepository {
  Future<Either<Failure, Course>> getCourseDetail(int courseId);
  Future<Either<Failure, List<CourseReview>>> getCourseReviews(int courseId);
  Future<Either<Failure, List<CourseReview>>> saveCourseReview({
    required int courseId,
    required double rating,
    required String reviewMessage,
  });
  Future<Either<Failure, bool>> saveContinueCourse({
    required int courseId,
    required bool isPurchased,
  });
  Future<Either<Failure, List<CourseSummary>>> getContinueCourses();
  Future<Either<Failure, List<CourseSummary>>> getMyCourses();
  Future<Either<Failure, bool>> rewatchCourse(int purchasedId);

  /// Records that the user finished a curriculum node (video watched ≥75%,
  /// PDF read ≥75% pages, image/assignment/zip loaded). Backend dedups
  /// on its side, but the client-side service still caches keys to avoid
  /// burning network on repeats within a session.
  Future<Either<Failure, bool>> recordContentCompletion({
    required int coursePurchasedId,
    required String jsonContentId,
  });

  /// Fetch the v2 pricing breakdown for one specific tier of a course.
  /// [priceId] picks one entry from `Course.pricing` (a tier's
  /// `coursePricingId`); the backend returns the tax / charges /
  /// total-payable for that tier.
  Future<Either<Failure, CoursePricing>> getCoursePricing(
    int courseId, {
    required int priceId,
    String? couponCode,
  });

  /// Resolves the signed HLS playback URL for a live class room. The
  /// [roomId] comes from the curriculum node's `url` field. Failures
  /// carry the HTTP status so the cubit can distinguish 403 (not
  /// enrolled), 404 (not found), 410 (not started / link expired) and
  /// 503 (streaming down).
  Future<Either<Failure, LivePlayback>> getLiveClassPlayback(String roomId);

  /// Mints a short-lived StreamApi JWT for the SignalR class hub. The
  /// student never holds the internal key — the proxy signs on their
  /// behalf. Returns the raw token string.
  Future<Either<Failure, String>> getStreamToken();

  /// Chat backfill for a live room, newest first. [beforeId] pages
  /// backwards (pass the oldest id currently on screen); [limit]
  /// defaults server-side to ~30.
  Future<Either<Failure, List<LiveChatMessage>>> getLiveClassChat(
    String roomId, {
    int? beforeId,
    int? limit,
  });

  /// Fetch the list of course categories and course types for filter options.
  Future<Either<Failure, CourseFilterData>> getCourseCategories();

  /// Fetch courses from the course catalog with optional filters.
  Future<Either<Failure, CourseCatalogResponse>> getCatalog({
    int? pageNo,
    String? searchQuery,
    String? courseType,
    int? categoryId,
    int? tileId,
    int? courseStatusType,
    CatalogSortBy? sortBy,
  });
}
