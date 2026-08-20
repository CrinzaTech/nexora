import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

/// Mints and caches the dedicated chat JWT used by the SignalR hub and
/// the chat-group REST endpoints. The repository persists the token in
/// [SessionService.chatToken] on success, so subsequent reads are
/// synchronous.
class GenerateChatTokenUseCase {
  final ChatGroupRepository repository;

  GenerateChatTokenUseCase(this.repository);

  /// [name] is the student's display name — surfaces in the token's
  /// claims so the backend can stamp it onto outbound messages.
  Future<Either<Failure, String>> call({String? name}) {
    return repository.generateChatToken(name: name);
  }
}
