import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';

/// Course bundles (B1–B3, P1, P2) and the related-item rails (X1, X2).
/// See BUNDLE_API.md.
abstract class BundleRepository {
  /// B1 — bundles on sale right now in the learner's organization.
  Future<Either<Failure, StorePage<BundleCard>>> getBundles({
    int pageNo = 1,
    int pageSize = 10,
  });

  /// B2 — the bundle page. A 404 (wrong id, another org's bundle, or one
  /// off sale that the learner never bought) carries `statusCode: 404`.
  Future<Either<Failure, BundleDetail>> getBundleDetail(int bundleId);

  /// B3 — bundles that contain [courseId], cheapest first. Empty when
  /// the course is in none.
  Future<Either<Failure, List<BundleCard>>> getBundlesForCourse(int courseId);

  /// P1 — create or reuse the Razorpay order. **No amount is sent**: the
  /// server prices the bundle from the database.
  Future<Either<Failure, BundleOrder>> createBundleOrder(int bundleId);

  /// P2 — **the only thing that unlocks the courses.** The three ids go
  /// out exactly as Razorpay handed them over.
  Future<Either<Failure, BundlePaymentResult>> verifyBundlePayment(
    int bundleId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

  /// X1 — Store products linked to a course.
  Future<Either<Failure, List<StoreProductCard>>> getCourseRelatedProducts(
    int courseId,
  );

  /// X2 — courses linked to a Store product (its public id).
  Future<Either<Failure, List<RelatedCourse>>> getProductRelatedCourses(
    String productId,
  );
}
