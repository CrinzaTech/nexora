import 'package:dartz/dartz.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/home/data/models/home_model.dart';

/// Home repository interface
abstract class HomeRepository {
  /// Get dashboard data
  Future<Either<Failure, DashboardData>> getDashboard();
}
