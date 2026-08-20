import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/domain/repositories/direct_chat_repository.dart';

part 'direct_inbox_state.dart';
part 'direct_inbox_cubit.freezed.dart';

const String _kDirectInboxLogTag = '[DirectInbox]';

/// App-level owner of the personal-chat inbox.
///
/// Registered as a **lazy singleton** rather than a per-screen factory,
/// which is the one structural difference from group chat's
/// `ChatGroupsCubit`. The reason is `DirectInboxUpdated`: unlike every
/// other hub event it is addressed to the user by id instead of a
/// joined group, so it lands whether or not the inbox screen is
/// mounted. A per-screen cubit would drop those updates the moment the
/// learner navigated away, and the unread counts would go stale.
///
/// Because it is a singleton, screens must provide it with
/// `BlocProvider.value` — a plain `BlocProvider` would close it on
/// dispose and every later `sl<DirectInboxCubit>()` would hand back a
/// dead cubit.
class DirectInboxCubit extends SafeCubit<DirectInboxState> {
  final DirectChatRepository _repository;
  final ChatGroupRepository _chatGroupRepository;
  final SignalRChatService _signalr;

  StreamSubscription<DmConversation>? _inboxSub;
  StreamSubscription<DirectBlockChangedEvent>? _blockSub;

  DirectInboxCubit({
    required DirectChatRepository repository,
    required ChatGroupRepository chatGroupRepository,
    required SignalRChatService signalr,
  }) : _repository = repository,
       _chatGroupRepository = chatGroupRepository,
       _signalr = signalr,
       super(const DirectInboxState.initial()) {
    // Subscribed in the constructor, never cancelled: the streams are
    // broadcast and this cubit lives as long as the app does. Wiring
    // here rather than in `load()` means a failed first fetch doesn't
    // also cost us real-time updates.
    _inboxSub = _signalr.onDirectInboxUpdated.listen(_onInboxUpdated);
    _blockSub = _signalr.onConversationBlockChanged.listen(_onBlockChanged);
  }

  /// Total unread across every thread — for a badge on the entry point.
  int get totalUnread => state.maybeWhen(
    loaded: (conversations, _) =>
        conversations.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );

  /// Bring the hub up, then fetch the inbox and the staff directory
  /// together. Safe to retry on error.
  Future<void> load() async {
    emit(const DirectInboxState.loading());
    await _ensureConnected();

    // Both fetches are independent — kick them off together and await
    // afterwards so the screen settles in one round-trip's worth of
    // latency, not two. (`Future.wait` would work too, but it collapses
    // the two Either types to their LUB and forces a cast back.)
    final conversationsFuture = _repository.getConversations();
    final directoryFuture = _repository.getDirectory();
    final conversationsResult = await conversationsFuture;
    final directoryResult = await directoryFuture;

    final conversationsFailure =
        conversationsResult.swap().toOption().toNullable();
    if (conversationsFailure != null) {
      debugPrint(
        '$_kDirectInboxLogTag load() conversations FAILED: '
        '${conversationsFailure.message}',
      );
      emit(DirectInboxState.error(conversationsFailure.message));
      return;
    }

    // A directory failure is soft: the learner can still read and reply
    // to threads they already have. Only the "start a new chat" picker
    // comes up empty.
    final directory = directoryResult.getOrElse(() => const []);

    emit(DirectInboxState.loaded(
      conversations: conversationsResult.getOrElse(() => const []),
      directory: directory,
    ));
  }

  /// Pull-to-refresh — re-fetches without dropping to `loading`, so the
  /// existing list stays on screen under the `RefreshIndicator`.
  Future<void> refresh() async {
    final conversationsFuture = _repository.getConversations();
    final directoryFuture = _repository.getDirectory();
    final conversationsResult = await conversationsFuture;
    final directoryResult = await directoryFuture;

    conversationsResult.fold(
      (failure) => emit(DirectInboxState.error(failure.message)),
      (conversations) => emit(DirectInboxState.loaded(
        conversations: conversations,
        directory: directoryResult.getOrElse(
          () => state.maybeWhen(
            loaded: (_, directory) => directory,
            orElse: () => const [],
          ),
        ),
      )),
    );
  }

  /// Resolve the thread for a directory entry, ready to navigate into.
  ///
  /// Prefers the thread already in the inbox (matched on the
  /// server-precomputed `conversationKey`) and only spends a
  /// `POST /conversations` when there isn't one. That call is
  /// idempotent server-side, so a race with the other party tapping
  /// "start conversation" at the same moment still yields one thread.
  Future<Either<Failure, DmConversation>> openWith(
    DmDirectoryEntry entry,
  ) async {
    final existing = state.maybeWhen(
      loaded: (conversations, _) {
        final index = conversations.indexWhere(
          (c) => c.conversationKey == entry.conversationKey,
        );
        return index >= 0 ? conversations[index] : null;
      },
      orElse: () => null,
    );
    if (existing != null) return Right(existing);

    final created = await _repository.startConversation(
      targetUserId: entry.userId,
    );
    return created.map((conversation) {
      _upsert(conversation);
      return conversation;
    });
  }

  /// Zero a thread's badge locally.
  ///
  /// Called by the room cubit when a message lands while the learner is
  /// already looking at the thread — the server read receipt is in
  /// flight, and without this the count would visibly flash to 1 and
  /// back.
  void clearUnread(String conversationKey) {
    state.maybeWhen(
      loaded: (conversations, directory) {
        final index = conversations.indexWhere(
          (c) => c.conversationKey == conversationKey,
        );
        if (index < 0 || conversations[index].unreadCount == 0) return;
        final next = [...conversations];
        next[index] = next[index].copyWith(unreadCount: 0);
        emit(DirectInboxState.loaded(
          conversations: next,
          directory: directory,
        ));
      },
      orElse: () {},
    );
  }

  /// Mirror a "clear my chat history" locally: blank the preview and
  /// zero the badge for [conversationKey].
  ///
  /// The server derives both from the same per-reader watermark the
  /// clear sets, so this agrees with the next refetch. `lastMessageAt`
  /// is deliberately left alone — the thread still had activity, the
  /// learner just can't see it any more.
  void markThreadCleared(String conversationKey) {
    state.maybeWhen(
      loaded: (conversations, directory) {
        final index = conversations.indexWhere(
          (c) => c.conversationKey == conversationKey,
        );
        if (index < 0) return;
        final next = [...conversations];
        next[index] = next[index].copyWith(
          lastMessagePreview: '',
          unreadCount: 0,
        );
        emit(DirectInboxState.loaded(
          conversations: next,
          directory: directory,
        ));
      },
      orElse: () {},
    );
  }

  /// Ensure the hub is up, minting a chat token first when the session
  /// doesn't have one. Mirrors `ChatRoomCubit.open()` step 1 — failures
  /// are logged and swallowed here because the REST inbox still renders
  /// fine without a socket; it just won't update live.
  Future<void> _ensureConnected() async {
    if (_signalr.isConnected) return;
    try {
      await _signalr.connect();
    } on StateError {
      debugPrint('$_kDirectInboxLogTag no chat token — minting via repo');
      final token = await _chatGroupRepository.generateChatToken();
      final failure = token.swap().toOption().toNullable();
      if (failure != null) {
        debugPrint(
          '$_kDirectInboxLogTag token mint FAILED: ${failure.message}',
        );
        return;
      }
      try {
        await _signalr.connect();
      } catch (e) {
        debugPrint('$_kDirectInboxLogTag reconnect FAILED: $e');
      }
    } catch (e) {
      debugPrint('$_kDirectInboxLogTag connect FAILED: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // SignalR -> cubit handlers
  // ───────────────────────────────────────────────────────────────────

  void _onInboxUpdated(DmConversation conversation) {
    debugPrint(
      '$_kDirectInboxLogTag <- DirectInboxUpdated '
      'key=${conversation.conversationKey} '
      'unread=${conversation.unreadCount}',
    );
    _upsert(conversation);
  }

  void _onBlockChanged(DirectBlockChangedEvent event) {
    state.maybeWhen(
      loaded: (conversations, directory) {
        final index = conversations.indexWhere(
          (c) => c.conversationKey == event.conversationKey,
        );
        if (index < 0) return;
        final next = [...conversations];
        next[index] = next[index].copyWith(isBlocked: event.isBlocked);
        emit(DirectInboxState.loaded(
          conversations: next,
          directory: directory,
        ));
      },
      orElse: () {},
    );
  }

  /// Insert or replace a thread, then re-apply the server's ordering
  /// (newest activity first; never-used threads to the top) so a
  /// pushed update lands where the next REST fetch would have put it.
  void _upsert(DmConversation conversation) {
    state.maybeWhen(
      loaded: (conversations, directory) {
        final next = [...conversations];
        final index = next.indexWhere(
          (c) => c.conversationKey == conversation.conversationKey,
        );
        if (index >= 0) {
          next[index] = conversation;
        } else {
          next.add(conversation);
        }
        next.sort((a, b) {
          final aAt = a.lastMessageAt;
          final bAt = b.lastMessageAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return -1;
          if (bAt == null) return 1;
          return bAt.compareTo(aAt);
        });
        emit(DirectInboxState.loaded(
          conversations: next,
          directory: directory,
        ));
      },
      // Nothing loaded yet — the next load() will pick this thread up
      // from REST, so there's nothing to merge into.
      orElse: () {},
    );
  }

  @override
  Future<void> close() async {
    await _inboxSub?.cancel();
    await _blockSub?.cancel();
    return super.close();
  }
}
