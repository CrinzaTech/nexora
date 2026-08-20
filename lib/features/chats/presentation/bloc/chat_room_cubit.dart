import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';

part 'chat_room_state.dart';
part 'chat_room_cubit.freezed.dart';

const String _kChatRoomLogTag = '[ChatRoom]';

/// One cubit per chat-room screen. Owns:
///   - the message list (paged) for the screen's [groupId]
///   - a SignalR subscription that pushes incoming `ReceiveMessage`
///     payloads into the list and forwards delete / typing events
///   - the join/leave lifecycle on the shared [SignalRChatService]
///
/// The chat token + SignalR connection are shared at the app level —
/// this cubit just hooks into them for the duration of one screen.
class ChatRoomCubit extends SafeCubit<ChatRoomState> {
  final ChatGroupRepository _repository;
  final SignalRChatService _signalr;
  final String groupId;

  static const int _pageSize = 50;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<ChatMessageDeletedEvent>? _deletedSub;
  StreamSubscription<ChatTypingEvent>? _typingSub;
  StreamSubscription<String>? _errorSub;

  /// Latest known typing-state for the room. Reflected on the loaded
  /// state so the UI can render a "Educator is typing…" hint.
  final Set<String> _typingUsers = <String>{};

  /// Message the user is currently composing a reply to, or null when
  /// the next send is a plain message. Exposed as a [ValueNotifier]
  /// rather than baked into [ChatRoomState] so the reply banner can
  /// listen without forcing the whole message list to rebuild on
  /// reply-start / reply-cancel.
  final ValueNotifier<ChatMessage?> replyingTo =
      ValueNotifier<ChatMessage?>(null);

  ChatRoomCubit({
    required ChatGroupRepository repository,
    required SignalRChatService signalr,
    required this.groupId,
  })  : _repository = repository,
        _signalr = signalr,
        super(const ChatRoomState.initial());

  /// Boot the screen: ensure the chat bearer is minted, hub is
  /// connected, history is loaded, and we've joined the room. Safe to
  /// retry on error.
  Future<void> open() async {
    debugPrint('$_kChatRoomLogTag open() groupId=$groupId');
    emit(const ChatRoomState.loading());

    // 1. Make sure the SignalR hub is up. `connect()` requires a chat
    // token to be cached; if it's missing we mint one via the repo
    // (which writes it to SessionService for the service to pick up).
    if (!_signalr.isConnected) {
      try {
        await _signalr.connect();
      } on StateError {
        debugPrint(
          '$_kChatRoomLogTag open() no chat token — minting via repo',
        );
        final token = await _repository.generateChatToken();
        final failure = token.swap().toOption().toNullable();
        if (failure != null) {
          debugPrint(
            '$_kChatRoomLogTag open() token mint FAILED: '
            '${failure.message}',
          );
          emit(ChatRoomState.error(failure.message));
          return;
        }
        try {
          await _signalr.connect();
        } catch (e) {
          debugPrint('$_kChatRoomLogTag open() reconnect FAILED: $e');
          emit(ChatRoomState.error('Could not connect to chat: $e'));
          return;
        }
      } catch (e) {
        debugPrint('$_kChatRoomLogTag open() connect FAILED: $e');
        emit(ChatRoomState.error('Could not connect to chat: $e'));
        return;
      }
    }

    // 2. Pull initial history (page 1).
    final history = await _repository.getMessages(
      groupId: groupId,
      page: 1,
      pageSize: _pageSize,
    );
    final maybeFailure = history.swap().toOption().toNullable();
    if (maybeFailure != null) {
      emit(ChatRoomState.error(maybeFailure.message));
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

    // 3. Join the room (after history, so the first ReceiveMessage
    // event can't slip in before the list is on screen).
    try {
      await _signalr.joinGroup(groupId);
    } catch (e) {
      debugPrint('$_kChatRoomLogTag open() joinGroup FAILED: $e');
      // Non-fatal — events for this room won't flow until reconnect,
      // but history is still visible.
    }

    // 4. Wire SignalR -> cubit streams. We accept events for any
    // group; the per-event handlers filter by [groupId].
    await _messageSub?.cancel();
    await _deletedSub?.cancel();
    await _typingSub?.cancel();
    await _errorSub?.cancel();
    _messageSub = _signalr.onMessage.listen(_onIncoming);
    _deletedSub = _signalr.onMessageDeleted.listen(_onDeleted);
    _typingSub = _signalr.onTyping.listen(_onTyping);
    _errorSub = _signalr.onError.listen(_onSignalRError);

    // 5. Push initial loaded state. Backend returns newest-first; the
    // UI list is rendered with `reverse: true`, so we keep the same
    // ordering in state (messages[0] == latest).
    emit(ChatRoomState.loaded(
      messages: paged.messages,
      hasMore: paged.hasMore,
      currentPage: paged.page,
      isLoadingMore: false,
      typingUserNames: const [],
    ));

    // 6. Mark the latest message as read.
    if (paged.messages.isNotEmpty) {
      try {
        await _signalr.markMessagesRead(
          groupId: groupId,
          lastMessageId: paged.messages.first.id,
        );
      } catch (_) {
        // Best-effort. Read receipts can lag without breaking the UI.
      }
    }
  }

  /// Append the next page of older history. No-op when the loaded
  /// state already shows `hasMore == false` or another page-load is
  /// in flight.
  Future<void> loadMore() async {
    final current = state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, typing) =>
          (messages, hasMore, currentPage, isLoadingMore, typing),
      orElse: () => null,
    );
    if (current == null) return;
    final (messages, hasMore, currentPage, isLoadingMore, typing) = current;
    if (!hasMore || isLoadingMore) return;

    emit(ChatRoomState.loaded(
      messages: messages,
      hasMore: hasMore,
      currentPage: currentPage,
      isLoadingMore: true,
      typingUserNames: typing,
    ));

    final nextPage = currentPage + 1;
    final result = await _repository.getMessages(
      groupId: groupId,
      page: nextPage,
      pageSize: _pageSize,
    );
    result.fold(
      (_) {
        // Soft-fail page-load: drop the spinner, keep the list.
        emit(ChatRoomState.loaded(
          messages: messages,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: false,
          typingUserNames: typing,
        ));
      },
      (paged) {
        emit(ChatRoomState.loaded(
          messages: [...messages, ...paged.messages],
          hasMore: paged.hasMore,
          currentPage: paged.page,
          isLoadingMore: false,
          typingUserNames: typing,
        ));
      },
    );
  }

  /// Send a plain-text message through the SignalR hub. Empty / whitespace
  /// input is silently dropped. When [replyingTo] is set, the in-flight
  /// reply target's id is included as `replyToMessageId` so the server
  /// can stitch the bubble back to its parent.
  Future<void> sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      debugPrint('$_kChatRoomLogTag sendText() empty input — dropped');
      return;
    }
    // Snapshot + clear the reply target eagerly so a slow send doesn't
    // strand a stale "Replying to …" banner over the composer.
    final reply = replyingTo.value;
    replyingTo.value = null;

    debugPrint(
      '$_kChatRoomLogTag sendText() groupId=$groupId '
      'connected=${_signalr.isConnected} len=${text.length} '
      'replyTo=${reply?.id}',
    );
    try {
      await _signalr.sendMessage(
        groupId: groupId,
        message: text,
        replyToMessageId: reply?.id,
      );
      debugPrint('$_kChatRoomLogTag sendText() invoke OK');
    } catch (e, st) {
      // Log loudly so we can diagnose why the bubble never lands. The
      // server will also fire a separate `Error` event for soft
      // rejections (e.g. canUserReply == false).
      debugPrint('$_kChatRoomLogTag sendText() FAILED: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Stage [msg] as the target of the next composed message. The reply
  /// banner reads off [replyingTo] and the send flow consumes it.
  void startReply(ChatMessage msg) {
    HapticFeedback.lightImpact();
    replyingTo.value = msg;
  }

  /// Drop the staged reply target without sending. Called from the
  /// banner's "x" affordance.
  void cancelReply() {
    if (replyingTo.value != null) {
      replyingTo.value = null;
    }
  }

  /// Server-side delete — the bubble disappears for everyone via
  /// `MessageDeleted`. The optimistic local removal happens in the
  /// `_onDeleted` handler so the same code path runs whether the
  /// student or another participant triggered the delete.
  Future<void> deleteMessage(int messageId) async {
    await _repository.deleteMessage(messageId: messageId, groupId: groupId);
  }

  /// Notify the other party that the user is typing. Call from the
  /// input's onChanged; cubit doesn't debounce — that's the widget's
  /// responsibility.
  Future<void> notifyTyping(bool typing) async {
    try {
      if (typing) {
        await _signalr.startTyping(groupId);
      } else {
        await _signalr.stopTyping(groupId);
      }
    } catch (_) {
      // Typing indicators are best-effort.
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // SignalR -> cubit handlers
  // ───────────────────────────────────────────────────────────────────

  void _onIncoming(ChatMessage msg) {
    if (msg.groupId != groupId) return;
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, typing) {
        // Dedup by id — `ReceiveMessage` fires for the sender too, so a
        // message we just sent and pushed optimistically could echo back.
        if (messages.any((m) => m.id == msg.id)) return;
        // WhatsApp-style nudge: a small selection-click haptic when a
        // genuinely new message lands while the user is on the chat
        // screen. Skipped for our own server-echoed messages so we
        // don't buzz on every send.
        if (!msg.isFromCurrentStudent) {
          HapticFeedback.selectionClick();
        }
        emit(ChatRoomState.loaded(
          messages: [msg, ...messages],
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          typingUserNames: typing,
        ));
        // Best-effort read receipt for the freshly arrived message.
        _signalr
            .markMessagesRead(groupId: groupId, lastMessageId: msg.id)
            .catchError((_) {});
      },
      orElse: () {},
    );
  }

  void _onDeleted(ChatMessageDeletedEvent event) {
    if (event.groupId != groupId) return;
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, typing) {
        final filtered =
            messages.where((m) => m.id != event.messageId).toList();
        if (filtered.length == messages.length) return;
        emit(ChatRoomState.loaded(
          messages: filtered,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          typingUserNames: typing,
        ));
      },
      orElse: () {},
    );
  }

  void _onTyping(ChatTypingEvent event) {
    if (event.groupId != groupId) return;
    if (event.typing) {
      _typingUsers.add(event.userName);
    } else {
      _typingUsers.remove(event.userName);
    }
    state.maybeWhen(
      loaded: (messages, hasMore, currentPage, isLoadingMore, _) {
        emit(ChatRoomState.loaded(
          messages: messages,
          hasMore: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
          typingUserNames: List<String>.unmodifiable(_typingUsers),
        ));
      },
      orElse: () {},
    );
  }

  void _onSignalRError(String message) {
    // Hook for future inline error banners. Today we let the user
    // discover failed sends via the UI (e.g. they don't see their
    // bubble appear) so we don't kick the cubit into an error state.
    debugPrint('$_kChatRoomLogTag <- server Error: $message');
  }

  @override
  Future<void> close() async {
    replyingTo.dispose();
    await _messageSub?.cancel();
    await _deletedSub?.cancel();
    await _typingSub?.cancel();
    await _errorSub?.cancel();
    try {
      await _signalr.leaveGroup(groupId);
    } catch (_) {}
    return super.close();
  }
}
