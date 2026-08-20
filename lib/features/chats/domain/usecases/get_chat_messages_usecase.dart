import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

/// Page through a chat room's history. Defaults match the backend's
/// page size of 50 so most callers can omit the args.
class GetChatMessagesUseCase {
  final ChatGroupRepository repository;

  GetChatMessagesUseCase(this.repository);

  Future<Either<Failure, PagedChatMessages>> call({
    required String groupId,
    int page = 1,
    int pageSize = 50,
  }) {
    return repository.getMessages(
      groupId: groupId,
      page: page,
      pageSize: pageSize,
    );
  }
}
