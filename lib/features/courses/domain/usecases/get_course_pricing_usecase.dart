import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';

class GetCoursePricingUseCase {
  final CourseRepository repository;

  GetCoursePricingUseCase(this.repository);

  Future<Either<Failure, CoursePricing>> call({
    required int courseId,
    required int priceId,
    String? couponCode,
  }) {
    return repository.getCoursePricing(courseId, priceId: priceId, couponCode: couponCode);
  }
}
