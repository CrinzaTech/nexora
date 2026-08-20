import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/chat_token_provider.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

class ChatGroupRepositoryImpl implements ChatGroupRepository {
  final ApiClient _apiClient;
  final ChatTokenProvider _tokenProvider;

  ChatGroupRepositoryImpl(this._apiClient, this._tokenProvider);

  @override
  Future<Either<Failure, List<ChatGroupModel>>> getChatGroups() async {
    try {
      final json = await _apiClient.getChatGroups();
      final data = json['data'] as List<dynamic>? ?? const [];
      final groups = data
          .whereType<Map<String, dynamic>>()
          .map(ChatGroupModel.fromJson)
          .toList();
      return Right(groups);
    } on DioException catch (e) {
      return Left(mapDioExceptionToFailure(e));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Pass-through to the shared [ChatTokenProvider]. Direct chat mints
  /// through the same provider, so there is exactly one place that
  /// talks to `/generate-token-v2` and writes `SessionService.chatToken`.
  @override
  Future<Either<Failure, String>> generateChatToken({String? name}) {
    return _tokenProvider.generateToken(name: name);
  }

  @override
  Future<Either<Failure, PagedChatMessages>> getMessages({
    required String groupId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.getChatMessages(
          header,
          groupId,
          page,
          pageSize,
        );
        // Backend usually wraps responses in `data`; accept both
        // wrapped and flat payloads.
        final payload = json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;
        return Right<Failure, PagedChatMessages>(
          PagedChatMessages.fromJson(payload),
        );
      } on DioException catch (e) {
        return Left<Failure, PagedChatMessages>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, PagedChatMessages>(
          Failure.unknown(message: e.toString()),
        );
      }
    });
  }

  @override
  Future<Either<Failure, bool>> deleteMessage({
    required int messageId,
    required String groupId,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        await _apiClient.deleteChatMessage(header, messageId, groupId);
        return const Right<Failure, bool>(true);
      } on DioException catch (e) {
        return Left<Failure, bool>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, bool>(Failure.unknown(message: e.toString()));
      }
    });
  }
}
