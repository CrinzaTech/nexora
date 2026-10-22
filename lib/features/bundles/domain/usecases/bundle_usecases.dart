import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/repositories/bundle_repository.dart';
import 'package:nexora/features/store/data/models/store_common_model.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';

/// B1 — bundles on sale.
class GetBundlesUseCase {
  final BundleRepository repository;

  GetBundlesUseCase(this.repository);

  Future<Either<Failure, StorePage<BundleCard>>> call({
    int pageNo = 1,
    int pageSize = 10,
  }) => repository.getBundles(pageNo: pageNo, pageSize: pageSize);
}

/// B2 — the bundle page.
class GetBundleDetailUseCase {
  final BundleRepository repository;

  GetBundleDetailUseCase(this.repository);

  Future<Either<Failure, BundleDetail>> call(int bundleId) =>
      repository.getBundleDetail(bundleId);
}

/// B3 — bundles containing a course.
class GetBundlesForCourseUseCase {
  final BundleRepository repository;

  GetBundlesForCourseUseCase(this.repository);

  Future<Either<Failure, List<BundleCard>>> call(int courseId) =>
      repository.getBundlesForCourse(courseId);
}

/// P1 — create (or reuse) the Razorpay order. Only on a Pay tap.
class CreateBundleOrderUseCase {
  final BundleRepository repository;

  CreateBundleOrderUseCase(this.repository);

  Future<Either<Failure, BundleOrder>> call(int bundleId) =>
      repository.createBundleOrder(bundleId);
}

/// P2 — verify the payment and unlock the courses.
class VerifyBundlePaymentUseCase {
  final BundleRepository repository;

  VerifyBundlePaymentUseCase(this.repository);

  Future<Either<Failure, BundlePaymentResult>> call(
    int bundleId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) => repository.verifyBundlePayment(
    bundleId,
    razorpayOrderId: razorpayOrderId,
    razorpayPaymentId: razorpayPaymentId,
    razorpaySignature: razorpaySignature,
  );
}

/// X1 — Store products linked to a course.
class GetCourseRelatedProductsUseCase {
  final BundleRepository repository;

  GetCourseRelatedProductsUseCase(this.repository);

  Future<Either<Failure, List<StoreProductCard>>> call(int courseId) =>
      repository.getCourseRelatedProducts(courseId);
}

/// X2 — courses linked to a Store product.
class GetProductRelatedCoursesUseCase {
  final BundleRepository repository;

  GetProductRelatedCoursesUseCase(this.repository);

  Future<Either<Failure, List<RelatedCourse>>> call(String productId) =>
      repository.getProductRelatedCourses(productId);
}
