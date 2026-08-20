import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

/// Soft-deletes a single chat message. The owning group id is
/// required so the backend can scope permissions.
class DeleteChatMessageUseCase {
  final ChatGroupRepository repository;

  DeleteChatMessageUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required int messageId,
    required String groupId,
  }) {
    return repository.deleteMessage(
      messageId: messageId,
      groupId: groupId,
    );
  }
}
