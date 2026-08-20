import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';

abstract class ChatGroupRepository {
  /// All groups the current user has access to.
  Future<Either<Failure, List<ChatGroupModel>>> getChatGroups();

  /// Mint the dedicated chat JWT used for every chat REST call and as
  /// the SignalR hub bearer. Cached on [SessionService.chatToken] by
  /// the implementation; callers usually just want the cached value.
  ///
  /// `name` is now a path segment on the backend (`/api/v1/generate-
  /// token-v2/{name}`). When omitted, the implementation resolves the
  /// logged-in student's display name from [ProfileCubit]; if neither
  /// is available it falls back to a generic placeholder so the URL
  /// still has a non-empty path segment (the API returns 404 when the
  /// segment is missing).
  Future<Either<Failure, String>> generateChatToken({String? name});

  /// Page through a room's message history. `page` is 1-indexed. The
  /// implementation pulls the chat bearer from [SessionService],
  /// generating it on demand if missing.
  Future<Either<Failure, PagedChatMessages>> getMessages({
    required String groupId,
    int page = 1,
    int pageSize = 50,
  });

  /// Soft-delete a single message. The owning room id is required so
  /// the backend can scope permissions correctly.
  Future<Either<Failure, bool>> deleteMessage({
    required int messageId,
    required String groupId,
  });
}
