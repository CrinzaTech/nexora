import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/auth/domain/repositories/org_code_repository.dart';

class OrgCodeRepositoryImpl implements OrgCodeRepository {
  final ApiClient _apiClient;

  OrgCodeRepositoryImpl(this._apiClient);

  @override
  Future<Either<Failure, bool>> validateOrgCode({
    required String orgCode,
  }) async {
    try {
      final json = await _apiClient.validateOrgCode({'orgCode': orgCode});

      // Response shape: { "message": "...", "data": { "isValid": true } }
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final isValid = data['isValid'];
        if (isValid == true) return const Right(true);
      }

      // Backend returned 200 but isValid is false — surface as a domain error
      // so the UI can show the "wrong code" message.
      final message =
          (json['message'] as String?)?.trim().isNotEmpty == true
              ? json['message'] as String
              : 'Invalid organisation code.';
      return Left(Failure.server(message: message));
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}
