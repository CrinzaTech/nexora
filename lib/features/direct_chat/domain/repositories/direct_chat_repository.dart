import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';

/// REST surface for personal (1-to-1) chat.
///
/// Every call is authorised with the shared chat token — the same JWT
/// group chat uses — so there is no separate login step for this
/// feature. The implementation mints it on demand via
/// `ChatTokenProvider`.
abstract class DirectChatRepository {
  /// The learner's inbox, newest-activity first. Threads that exist but
  /// have no messages yet sort to the top.
  Future<Either<Failure, List<DmConversation>>> getConversations();

  /// Open a thread with [targetUserId] (a `users.id` taken from
  /// [getDirectory]) — or return the existing one.
  ///
  /// **Idempotent**: calling it twice yields the same thread, so it is
  /// safe to fire on every screen entry. A `404` means the target is
  /// not a member of this org; surface "not available for messaging"
  /// and do not retry.
  Future<Either<Failure, DmConversation>> startConversation({
    required int targetUserId,
  });

  /// Staff the learner may message. `search` / `limit` exist on the
  /// endpoint but are ignored for the learner side, so they aren't
  /// exposed here — filter client-side.
  Future<Either<Failure, List<DmDirectoryEntry>>> getDirectory();

  /// Page through one thread's history. `page` is 1-indexed and the
  /// payload is byte-identical to group chat, so [PagedChatMessages]
  /// parses it unchanged. Note each message's `groupId` carries the
  /// conversation key — an inherited field name, not a bug.
  Future<Either<Failure, PagedChatMessages>> getMessages({
    required String conversationKey,
    int page = 1,
    int pageSize = 50,
  });

  /// Unread badge for a single thread.
  Future<Either<Failure, int>> getUnreadCount({
    required String conversationKey,
  });

  /// Soft-delete one of the learner's own messages, **removing it for
  /// both sides**, within 24 hours of sending. The backend refuses
  /// anyone else's messages and anything older than the window.
  ///
  /// Not to be confused with [clearHistory] — see the class docs on
  /// `DirectChatRoomCubit` for the distinction that matters to users.
  Future<Either<Failure, bool>> deleteMessage({
    required int messageId,
    required String conversationKey,
  });

  /// Rewrite one of the learner's own **text** messages, within 2
  /// minutes of sending. Returns the full updated message.
  ///
  /// Author-only: there is deliberately no staff override, because
  /// rewriting words that stay attributed to someone else is
  /// misrepresentation. Refused with `403` for a non-author, a deleted
  /// message, a non-text message or a late edit; `400` for empty text.
  ///
  /// An empty [message] must never be silently converted into a delete
  /// — that is a separate, confirmed action.
  Future<Either<Failure, ChatMessage>> editMessage({
    required int messageId,
    required String conversationKey,
    required String message,
  });

  /// Hide this thread's history from the **caller only**. The staff
  /// member keeps the full conversation.
  ///
  /// A server-side per-reader watermark, not a delete: it survives a
  /// reinstall, and it is reversible server-side. Returns the
  /// `clearedUpToMessageId` watermark the server set.
  Future<Either<Failure, int>> clearHistory({
    required String conversationKey,
  });

  /// Clear a thread's badge over REST. Prefer the hub's
  /// `MarkDirectRead` while a room is open; this is the no-socket path.
  Future<Either<Failure, bool>> markRead({
    required String conversationKey,
    required int lastReadMessageId,
  });
}
