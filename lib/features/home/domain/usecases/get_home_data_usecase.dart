import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/home/data/models/home_model.dart';
import 'package:nexora/features/home/domain/repositories/home_repository.dart';

class GetHomeDataUseCase {
  final HomeRepository repository;

  GetHomeDataUseCase(this.repository);

  Future<Either<Failure, DashboardData>> call() {
    return repository.getDashboard();
  }
}
