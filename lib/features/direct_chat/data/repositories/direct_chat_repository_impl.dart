import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/network/network_exception_mapper.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/chat_token_provider.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/domain/repositories/direct_chat_repository.dart';

class DirectChatRepositoryImpl implements DirectChatRepository {
  final ApiClient _apiClient;
  final ChatTokenProvider _tokenProvider;

  DirectChatRepositoryImpl(this._apiClient, this._tokenProvider);

  /// Conversation keys contain `:` characters. They route fine
  /// literally, but encoding removes all doubt for the calls that
  /// interpolate the key into the **path**.
  ///
  /// Only apply this to path parameters — Dio already encodes query
  /// parameters, so passing an encoded key there would double-encode
  /// it and the backend would look up a thread that doesn't exist.
  String _encodeKey(String conversationKey) =>
      Uri.encodeComponent(conversationKey);

  @override
  Future<Either<Failure, List<DmConversation>>> getConversations() async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        // Bare JSON array — this endpoint is not `data`-wrapped.
        final list = await _apiClient.getDirectConversations(header);
        final conversations = list
            .whereType<Map>()
            .map((e) => DmConversation.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return Right<Failure, List<DmConversation>>(conversations);
      } on DioException catch (e) {
        return Left<Failure, List<DmConversation>>(
          mapDioExceptionToFailure(e),
        );
      } catch (e) {
        return Left<Failure, List<DmConversation>>(
          Failure.unknown(message: e.toString()),
        );
      }
    });
  }

  @override
  Future<Either<Failure, DmConversation>> startConversation({
    required int targetUserId,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.startDirectConversation(header, {
          'targetUserId': targetUserId,
        });
        // Accept both a `data`-wrapped and a flat payload — the inbox
        // endpoint is bare, this one is documented flat, and the two
        // have drifted before.
        final payload = json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json;
        return Right<Failure, DmConversation>(
          DmConversation.fromJson(payload),
        );
      } on DioException catch (e) {
        // A 404 here means the target isn't in this org. Replace the
        // generic mapper copy with something the learner can act on.
        if (e.response?.statusCode == 404) {
          return Left<Failure, DmConversation>(
            Failure.server(
              message: 'This person is not available for messaging.',
              statusCode: 404,
            ),
          );
        }
        return Left<Failure, DmConversation>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, DmConversation>(
          Failure.unknown(message: e.toString()),
        );
      }
    });
  }

  @override
  Future<Either<Failure, List<DmDirectoryEntry>>> getDirectory() async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final list = await _apiClient.getDirectDirectory(header);
        final entries = list
            .whereType<Map>()
            .map((e) => DmDirectoryEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return Right<Failure, List<DmDirectoryEntry>>(entries);
      } on DioException catch (e) {
        return Left<Failure, List<DmDirectoryEntry>>(
          mapDioExceptionToFailure(e),
        );
      } catch (e) {
        return Left<Failure, List<DmDirectoryEntry>>(
          Failure.unknown(message: e.toString()),
        );
      }
    });
  }

  @override
  Future<Either<Failure, PagedChatMessages>> getMessages({
    required String conversationKey,
    int page = 1,
    int pageSize = 50,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.getDirectMessages(
          header,
          _encodeKey(conversationKey),
          page,
          pageSize,
        );
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
  Future<Either<Failure, int>> getUnreadCount({
    required String conversationKey,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.getDirectUnreadCount(
          header,
          _encodeKey(conversationKey),
        );
        final payload = json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;
        return Right<Failure, int>(
          (payload['unreadCount'] as num?)?.toInt() ?? 0,
        );
      } on DioException catch (e) {
        return Left<Failure, int>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, int>(Failure.unknown(message: e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, bool>> deleteMessage({
    required int messageId,
    required String conversationKey,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        // `conversationKey` is a QUERY param here — pass it raw and let
        // Dio encode it exactly once.
        await _apiClient.deleteDirectMessage(
          header,
          messageId,
          conversationKey,
        );
        return const Right<Failure, bool>(true);
      } on DioException catch (e) {
        // The 24-hour window lives in SQL, so a stale screen or a
        // wound-back device clock lands here with a 404 rather than the
        // "not found" the mapper would otherwise report.
        if (e.response?.statusCode == 404) {
          return Left<Failure, bool>(
            Failure.server(
              message:
                  'This message can no longer be deleted. Messages can only '
                  'be deleted within 24 hours of sending.',
              statusCode: 404,
            ),
          );
        }
        return Left<Failure, bool>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, bool>(Failure.unknown(message: e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, ChatMessage>> editMessage({
    required int messageId,
    required String conversationKey,
    required String message,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.editDirectMessage(header, messageId, {
          // Body field — sent raw, JSON-encoded by Dio. No URL encoding.
          'conversationKey': conversationKey,
          'message': message,
        });
        final payload = json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json;
        return Right<Failure, ChatMessage>(ChatMessage.fromJson(payload));
      } on DioException catch (e) {
        // The server owns the 2-minute window and the author check, and
        // a device with a wound-back clock will still get refused here
        // even though the app offered the affordance. Say something the
        // learner can act on rather than echoing a raw status.
        final status = e.response?.statusCode;
        if (status == 403) {
          return Left<Failure, ChatMessage>(
            Failure.server(
              message:
                  'This message can no longer be edited. Messages can only '
                  'be edited by their sender, within 2 minutes of sending.',
              statusCode: 403,
            ),
          );
        }
        if (status == 400) {
          return Left<Failure, ChatMessage>(
            Failure.server(
              message:
                  'An edited message cannot be empty. Use delete instead.',
              statusCode: 400,
            ),
          );
        }
        return Left<Failure, ChatMessage>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, ChatMessage>(
          Failure.unknown(message: e.toString()),
        );
      }
    });
  }

  @override
  Future<Either<Failure, int>> clearHistory({
    required String conversationKey,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        final json = await _apiClient.clearDirectConversation(
          header,
          _encodeKey(conversationKey),
        );
        final payload = json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;
        return Right<Failure, int>(
          (payload['clearedUpToMessageId'] as num?)?.toInt() ?? 0,
        );
      } on DioException catch (e) {
        return Left<Failure, int>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, int>(Failure.unknown(message: e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, bool>> markRead({
    required String conversationKey,
    required int lastReadMessageId,
  }) async {
    final bearerResult = await _tokenProvider.ensureBearer();
    return bearerResult.fold((failure) => Left(failure), (header) async {
      try {
        await _apiClient.markDirectConversationRead(
          header,
          _encodeKey(conversationKey),
          lastReadMessageId,
        );
        return const Right<Failure, bool>(true);
      } on DioException catch (e) {
        return Left<Failure, bool>(mapDioExceptionToFailure(e));
      } catch (e) {
        return Left<Failure, bool>(Failure.unknown(message: e.toString()));
      }
    });
  }
}
