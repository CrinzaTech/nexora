import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';
import 'package:nexora/features/direct_chat/domain/repositories/direct_chat_repository.dart';
import 'package:nexora/features/direct_chat/presentation/bloc/direct_inbox_cubit.dart';

part 'direct_chat_room_state.dart';
part 'direct_chat_room_cubit.freezed.dart';

const String _kDirectRoomLogTag = '[DirectRoom]';

/// One cubit per personal-chat screen. Owns:
///   - the message list (paged) for the screen's [conversationKey]
///   - a SignalR subscription that pushes incoming
///     `ReceiveDirectMessage` payloads into the list and forwards
///     delete / typing / block events
///   - the join/leave lifecycle on the shared [SignalRChatService]
///
/// Structurally a sibling of `ChatRoomCubit`, deliberately kept as a
/// separate class rather than a subclass: the lifecycle has the same
/// shape but the keys, hub methods and events all differ, and sharing a
/// base class would make it easy to send a private message down a
/// group-chat code path.
///
/// ## Delete vs clear — do not conflate these
///
/// [deleteMessage] removes **one message for both sides**: the staff
/// member watches it vanish too, it is irreversible, and it is only
/// allowed within 24 hours.
///
/// [clearHistory] hides **the whole thread from this learner only**:
/// the staff member keeps everything, it is a server-side watermark
/// rather than a deletion, it survives a reinstall, and it is
/// reversible server-side.
///
/// One destroys the other person's copy and the other does not, so the
/// confirm copy in the UI has to say which is which.
class DirectChatRoomCubit extends SafeCubit<DirectChatRoomState> {
  final DirectChatRepository _repository;
  final ChatGroupRepository _chatGroupRepository;
  final SignalRChatService _signalr;
  final DirectInboxCubit _inbox;
  final String conversationKey;

  /// Blocked flag as known at screen-open time (from the inbox card).
  /// Live changes arrive on `DirectConversationBlockChanged`.
  final bool initiallyBlocked;

  static const int _pageSize = 50;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<ChatMessage>? _editedSub;
  StreamSubscription<DirectMessageDeletedEvent>? _deletedSub;
  StreamSubscription<DirectTypingEvent>? _typingSub;
  StreamSubscription<DirectBlockChangedEvent>? _blockSub;
  StreamSubscription<String>? _errorSub;

  /// Latest known typing-state for the thread. Reflected on the loaded
  /// state so the UI can render a "Priya is typing…" hint.
  final Set<String> _typingUsers = <String>{};

  /// Message the user is currently composing a reply to, or null when
  /// the next send is a plain message. Exposed as a [ValueNotifier]
  /// rather than baked into [DirectChatRoomState] so the reply banner
  /// can listen without forcing the whole message list to rebuild on
  /// reply-start / reply-cancel.
  final ValueNotifier<ChatMessage?> replyingTo =
      ValueNotifier<ChatMessage?>(null);

  /// Message the user is currently rewriting, or null when the composer
  /// is in its normal send mode. Kept out of the freezed state for the
  /// same reason as [replyingTo] — the edit banner and the composer
  /// listen, the message list doesn't rebuild.
  ///
  /// Mutually exclusive with [replyingTo]: staging one clears the
  /// other, because "send" can't mean both at once.
  final ValueNotifier<ChatMessage?> editingMessage =
      ValueNotifier<ChatMessage?>(null);

  /// Last server-side refusal, for a one-shot snackbar. A blocked send
  /// comes back as an `Error` event, not an exception — the `invoke`
  /// returns normally — so this is the only channel the UI has to tell
  /// the learner their message didn't land. Edit and delete refusals
  /// (a late edit, a wound-back device clock) land here too.
  final ValueNotifier<String?> sendError = ValueNotifier<String?>(null);

  /// One-shot confirmation for actions with no visible echo of their
  /// own, so the learner knows a clear actually happened.
  final ValueNotifier<String?> actionNotice = ValueNotifier<String?>(null);

  DirectChatRoomCubit({
    required DirectChatRepository repository,
    required ChatGroupRepository chatGroupRepository,
    required SignalRChatService signalr,
    required DirectInboxCubit inbox,
    required this.conversationKey,
    this.initiallyBlocked = false,
  }) : _repository = repository,
       _chatGroupRepository = chatGroupRepository,
       _signalr = signalr,
       _inbox = inbox,
       super(const DirectChatRoomState.initial());

  /// Boot the screen: ensure the chat bearer is minted, hub is
  /// connected, history is loaded, and we've joined the thread. Safe to
  /// retry on error.
  Future<void> open() async {
    debugPrint('$_kDirectRoomLogTag open() key=$conversationKey');
    emit(const DirectChatRoomState.loading());

    // 1. Make sure the SignalR hub is up. `connect()` requires a chat
    // token to be cached; if it's missing we mint one via the group
    // chat repo — personal chat reuses the exact same token, so there
    // is deliberately no second mint path here.
    if (!_signalr.isConnected) {
      try {
        await _signalr.connect();
      } on StateError {
        debugPrint('$_kDirectRoomLogTag open() no chat token — minting');
        final token = await _chatGroupRepository.generateChatToken();
        final failure = token.swap().toOption().toNullable();
        if (failure != null) {
          debugPrint(
            '$_kDirectRoomLogTag open() token mint FAILED: '
            '${failure.message}',
          );
          emit(DirectChatRoomState.error(failure.message));
          return;
        }
        try {
          await _signalr.connect();
        } catch (e) {
          debugPrint('$_kDirectRoomLogTag open() reconnect FAILED: $e');
          emit(DirectChatRoomState.error('Could not connect to chat: $e'));
          return;
        }
      } catch (e) {
        debugPrint('$_kDirectRoomLogTag open() connect FAILED: $e');
        emit(DirectChatRoomState.error('Could not connect to chat: $e'));
        return;
      }
    }

    // 2. Pull initial history (page 1).
    final history = await _repository.getMessages(
      conversationKey: conversationKey,
      page: 1,
      pageSize: _pageSize,
    );
    final maybeFailure = history.swap().toOption().toNullable();
    if (maybeFailure != null) {
      emit(DirectChatRoomState.error(maybeFailure.message));
      return;
    }
    final paged = history.getOrElse(
      () => const PagedChatMessages(
        messages: [],
        page: 1,
        pageSize: _pageSize,
        hasMore: false,
      ),
    );

    // 3. Join the thread (after history, so the first
    // ReceiveDirectMessage can't slip in before the list is on screen).
    try {
      await _signalr.joinConversation(conversationKey);
    } catch (e) {
      debugPrint('$_kDirectRoomLogTag open() joinConversation FAILED: $e');
      // Non-fatal — events won't flow until reconnect, but history is
      // still visible.
    }

    // 4. Wire SignalR -> cubit streams. We accept events for any
    // thread; the per-event handlers filter by [conversationKey].
    await _messageSub?.cancel();
    await _editedSub?.cancel();
    await _deletedSub?.cancel();
    await _typingSub?.cancel();
    await _blockSub?.cancel();
    await _errorSub?.cancel();
    _messageSub = _signalr.onDirectMessage.listen(_onIncoming);
    _editedSub = _signalr.onDirectMessageEdited.listen(_onEdited);
    _deletedSub = _signalr.onDirectMessageDeleted.listen(_onDeleted);
    _typingSub = _signalr.onDirectTyping.listen(_onTyping);
    _blockSub = _signalr.onConversationBlockChanged.listen(_onBlockChanged);
    _errorSub = _signalr.onError.listen(_onSignalRError);

    // 5. Push initial loaded state. Backend returns newest-first; the
    // UI list is rendered with `reverse: true`, so we keep the same
    // ordering in state (messages[0] == latest).
    emit(DirectChatRoomState.loaded(
      messages: paged.messages,
      hasMore: paged.hasMore,
      currentPage: paged.page,
      isLoadingMore: false,
      isBlocked: initiallyBlocked,
      typingUserNames: const [],
    ));

    // 6. Mark the latest message as read, and zero the badge locally so
    // the inbox doesn't show a count for the thread we're looking at.
    if (paged.messages.isNotEmpty) {
      _inbox.clearUnread(conversationKey);
      try {
        await _signalr.markDirectRead(
          conversationKey: conversationKey,
          lastReadMessageId: paged.messages.first.id,
        );
      } catch (_) {
        // Best-effort. Read receipts can lag without breaking the UI.
      }
    }
  }

  /// Append the next page of older history. No-op when the loaded state
  /// already shows `hasMore == false` or another page-load is in
  /// flight.
  Future<void> loadMore() async {
    final current = state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing) =>
          (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing),
      orElse: () => null,
    );
    if (current == null) return;
    final (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing) =
        current;
    if (!hasMore || isLoadingMore) return;

    emit(DirectChatRoomState.loaded(
      messages: messages,
      hasMore: hasMore,
      currentPage: currentPage,
      isLoadingMore: true,
      isBlocked: isBlocked,
      typingUserNames: typing,
    ));

    final nextPage = currentPage + 1;
    final result = await _repository.getMessages(
      conversationKey: conversationKey,
      page: nextPage,
      pageSize: _pageSize,
    );
    result.fold(
      (_) {
        // Soft-fail page-load: drop the spinner, keep the list.
        emit(DirectChatRoomState.loaded(
          messages: messages,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: false,
          isBlocked: isBlocked,
          typingUserNames: typing,
        ));
      },
      (paged) {
        emit(DirectChatRoomState.loaded(
          messages: [...messages, ...paged.messages],
          hasMore: paged.hasMore,
          currentPage: paged.page,
          isLoadingMore: false,
          isBlocked: isBlocked,
          typingUserNames: typing,
        ));
      },
    );
  }

  /// Send a plain-text message through the SignalR hub. Empty /
  /// whitespace input is silently dropped. When [replyingTo] is set,
  /// the in-flight reply target's id travels as `replyToMessageId` so
  /// the server can stitch the bubble back to its parent.
  Future<void> sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      debugPrint('$_kDirectRoomLogTag sendText() empty input — dropped');
      return;
    }
    // Snapshot + clear the reply target eagerly so a slow send doesn't
    // strand a stale "Replying to …" banner over the composer.
    final reply = replyingTo.value;
    replyingTo.value = null;

    debugPrint(
      '$_kDirectRoomLogTag sendText() key=$conversationKey '
      'connected=${_signalr.isConnected} len=${text.length} '
      'replyTo=${reply?.id}',
    );
    try {
      await _signalr.sendDirectMessage(
        conversationKey: conversationKey,
        message: text,
        replyToMessageId: reply?.id,
      );
      debugPrint('$_kDirectRoomLogTag sendText() invoke OK');
    } catch (e, st) {
      debugPrint('$_kDirectRoomLogTag sendText() FAILED: $e');
      debugPrintStack(stackTrace: st);
      sendError.value = 'Message could not be sent. Please try again.';
    }
  }

  /// Stage [msg] as the target of the next composed message.
  void startReply(ChatMessage msg) {
    HapticFeedback.lightImpact();
    // Replying and editing both own the composer — never both at once.
    editingMessage.value = null;
    replyingTo.value = msg;
  }

  /// Drop the staged reply target without sending.
  void cancelReply() {
    if (replyingTo.value != null) {
      replyingTo.value = null;
    }
  }

  /// Load [msg] into the composer for rewriting.
  void startEdit(ChatMessage msg) {
    HapticFeedback.lightImpact();
    replyingTo.value = null;
    editingMessage.value = msg;
  }

  /// Leave edit mode without saving.
  void cancelEdit() {
    if (editingMessage.value != null) {
      editingMessage.value = null;
    }
  }

  /// Commit a rewrite of the staged [editingMessage].
  ///
  /// An empty body is **refused, never converted into a delete** —
  /// deletion is a separate, confirmed action and silently swapping one
  /// for the other is a nasty surprise.
  ///
  /// The list is patched from the server's response rather than
  /// optimistically: the same message also arrives on
  /// `DirectMessageEdited` (we're a member of the thread), and matching
  /// on id makes applying it twice a no-op.
  Future<void> saveEdit(String raw) async {
    final target = editingMessage.value;
    if (target == null) return;
    final text = raw.trim();
    if (text.isEmpty) {
      sendError.value =
          'An edited message cannot be empty. Use delete instead.';
      return;
    }
    if (text == target.message.trim()) {
      // Nothing changed — don't spend a round-trip or stamp `editedAt`
      // on a message the author didn't actually alter.
      editingMessage.value = null;
      return;
    }

    debugPrint(
      '$_kDirectRoomLogTag saveEdit() id=${target.id} len=${text.length}',
    );
    final result = await _repository.editMessage(
      messageId: target.id,
      conversationKey: conversationKey,
      message: text,
    );
    result.fold(
      (failure) {
        debugPrint('$_kDirectRoomLogTag saveEdit() FAILED: ${failure.message}');
        sendError.value = failure.message;
        // Leave edit mode either way: the window has almost certainly
        // closed, so keeping the composer primed would just invite a
        // second refusal.
        editingMessage.value = null;
      },
      (updated) {
        editingMessage.value = null;
        _replaceMessage(updated);
      },
    );
  }

  /// Server-side delete — **removes the message for both sides**,
  /// within 24 hours of sending. The bubble disappears for everyone via
  /// `DirectMessageDeleted`, so the local removal runs through the same
  /// handler regardless of who triggered it.
  ///
  /// A learner may only delete their own messages. The window and the
  /// author check are both enforced in SQL, so a stale screen or a
  /// wound-back device clock still gets refused — surface that rather
  /// than assuming it can't happen.
  Future<void> deleteMessage(int messageId) async {
    final result = await _repository.deleteMessage(
      messageId: messageId,
      conversationKey: conversationKey,
    );
    result.fold(
      (failure) {
        debugPrint(
          '$_kDirectRoomLogTag deleteMessage() FAILED: ${failure.message}',
        );
        sendError.value = failure.message;
      },
      (_) {
        // The server broadcasts `DirectMessageDeleted` to the other
        // party but not back to the caller — we already know — so the
        // local removal has to happen here.
        _removeMessage(messageId);
      },
    );
  }

  /// Hide the whole thread from **this learner only**. The staff member
  /// keeps the full conversation.
  ///
  /// This is a server call with a persistent watermark, not a local
  /// list reset: reinstall the app, log back in, and the cleared
  /// messages stay hidden. Nothing is broadcast — a clear is nobody
  /// else's business.
  Future<void> clearHistory() async {
    final result = await _repository.clearHistory(
      conversationKey: conversationKey,
    );
    result.fold(
      (failure) {
        debugPrint(
          '$_kDirectRoomLogTag clearHistory() FAILED: ${failure.message}',
        );
        sendError.value = failure.message;
      },
      (clearedUpToMessageId) {
        debugPrint(
          '$_kDirectRoomLogTag clearHistory() OK '
          'upTo=$clearedUpToMessageId',
        );
        state.maybeWhen(
          loaded: (_, __, ___, ____, isBlocked, typing) {
            emit(DirectChatRoomState.loaded(
              messages: const [],
              // The watermark hides everything up to now, so there is
              // no older page left to fetch.
              hasMore: false,
              currentPage: 1,
              isLoadingMore: false,
              isBlocked: isBlocked,
              typingUserNames: typing,
            ));
          },
          orElse: () {},
        );
        // The server derives the inbox row's preview and unread count
        // from the same watermark, so mirroring it locally keeps us
        // agreeing with the next refetch.
        _inbox.markThreadCleared(conversationKey);
        actionNotice.value = 'Chat history cleared from your side.';
      },
    );
  }

  /// Notify the other party that the user is typing. Debouncing is the
  /// input widget's responsibility, matching group chat.
  Future<void> notifyTyping(bool typing) async {
    try {
      if (typing) {
        await _signalr.startTypingDirect(conversationKey);
      } else {
        await _signalr.stopTypingDirect(conversationKey);
      }
    } catch (_) {
      // Typing indicators are best-effort.
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // SignalR -> cubit handlers
  // ───────────────────────────────────────────────────────────────────

  void _onIncoming(ChatMessage msg) {
    // `groupId` carries the conversation key on a DM — inherited field
    // name, shared table.
    if (msg.groupId != conversationKey) return;
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing) {
        // Dedup by id — `ReceiveDirectMessage` fires for the sender
        // too, so a message we just sent echoes back.
        if (messages.any((m) => m.id == msg.id)) return;
        if (!msg.isFromCurrentStudent) {
          HapticFeedback.selectionClick();
        }
        emit(DirectChatRoomState.loaded(
          messages: [msg, ...messages],
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          isBlocked: isBlocked,
          typingUserNames: typing,
        ));
        // The learner is looking at the thread, so zero the badge
        // locally as well as telling the server — otherwise the count
        // flashes to 1 and back while the receipt is in flight.
        _inbox.clearUnread(conversationKey);
        _signalr
            .markDirectRead(
              conversationKey: conversationKey,
              lastReadMessageId: msg.id,
            )
            .catchError((_) {});
      },
      orElse: () {},
    );
  }

  void _onEdited(ChatMessage updated) {
    // `groupId` carries the conversation key on a DM.
    if (updated.groupId != conversationKey) return;
    // Fires for our own edits too, since we're a member of the thread.
    // Matching on id makes a second application a no-op.
    _replaceMessage(updated);
  }

  void _onDeleted(DirectMessageDeletedEvent event) {
    if (event.conversationKey != conversationKey) return;
    _removeMessage(event.messageId);
  }

  /// Swap a message in place by id, preserving list position. Note the
  /// quoted preview inside *other* messages' `replyTo` is built by the
  /// server at read time, so an already-rendered quote keeps the old
  /// text until the next reload — known and accepted.
  void _replaceMessage(ChatMessage updated) {
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing) {
        final index = messages.indexWhere((m) => m.id == updated.id);
        if (index < 0) return;
        final next = [...messages];
        next[index] = updated;
        emit(DirectChatRoomState.loaded(
          messages: next,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          isBlocked: isBlocked,
          typingUserNames: typing,
        ));
      },
      orElse: () {},
    );
  }

  void _removeMessage(int messageId) {
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, isBlocked, typing) {
        final filtered = messages.where((m) => m.id != messageId).toList();
        if (filtered.length == messages.length) return;
        emit(DirectChatRoomState.loaded(
          messages: filtered,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          isBlocked: isBlocked,
          typingUserNames: typing,
        ));
      },
      orElse: () {},
    );
  }

  void _onTyping(DirectTypingEvent event) {
    if (event.conversationKey != conversationKey) return;
    if (event.typing) {
      _typingUsers.add(event.userName);
    } else {
      _typingUsers.remove(event.userName);
    }
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, isBlocked, _) {
        emit(DirectChatRoomState.loaded(
          messages: messages,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          isBlocked: isBlocked,
          typingUserNames: List<String>.unmodifiable(_typingUsers),
        ));
      },
      orElse: () {},
    );
  }

  void _onBlockChanged(DirectBlockChangedEvent event) {
    if (event.conversationKey != conversationKey) return;
    debugPrint(
      '$_kDirectRoomLogTag <- block changed isBlocked=${event.isBlocked}',
    );
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, _, typing) {
        emit(DirectChatRoomState.loaded(
          messages: messages,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          isBlocked: event.isBlocked,
          typingUserNames: typing,
        ));
      },
      orElse: () {},
    );
  }

  void _onSignalRError(String message) {
    // There is one `Error` channel on the hub, shared with group chat,
    // so this payload does not necessarily belong to this thread. In
    // practice only one chat screen is active at a time, which makes it
    // tolerable — but it is why we surface generic copy rather than
    // echoing the server's text into the thread.
    debugPrint('$_kDirectRoomLogTag <- server Error: $message');
    sendError.value = message;
  }

  @override
  Future<void> close() async {
    replyingTo.dispose();
    editingMessage.dispose();
    sendError.dispose();
    actionNotice.dispose();
    await _messageSub?.cancel();
    await _editedSub?.cancel();
    await _deletedSub?.cancel();
    await _typingSub?.cancel();
    await _blockSub?.cancel();
    await _errorSub?.cancel();
    try {
      await _signalr.leaveConversation(conversationKey);
    } catch (_) {}
    return super.close();
  }
}
