import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

class GetChatGroupsUseCase {
  final ChatGroupRepository repository;

  GetChatGroupsUseCase(this.repository);

  Future<Either<Failure, List<ChatGroupModel>>> call() {
    return repository.getChatGroups();
  }
}
