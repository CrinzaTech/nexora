import 'dart:async';

import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Tag used on every chat-transport debugPrint. Grep for `[ChatHub]`
/// in `flutter logs` to isolate the SignalR conversation.
const String _kChatLogTag = '[ChatHub]';

/// Payload pushed to [SignalRChatService.onMessageDeleted].
class ChatMessageDeletedEvent {
  final String groupId;
  final int messageId;
  const ChatMessageDeletedEvent({
    required this.groupId,
    required this.messageId,
  });
}

/// Payload pushed to [SignalRChatService.onTyping].
class ChatTypingEvent {
  final String groupId;
  final int userId;
  final String userRole;
  final String userName;
  final bool typing;
  const ChatTypingEvent({
    required this.groupId,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.typing,
  });
}

/// Payload pushed to [SignalRChatService.onMessagesRead].
class ChatMessagesReadEvent {
  final String groupId;
  final int readByUserId;
  final String readByRole;
  final int lastReadMessageId;
  final DateTime readAt;
  const ChatMessagesReadEvent({
    required this.groupId,
    required this.readByUserId,
    required this.readByRole,
    required this.lastReadMessageId,
    required this.readAt,
  });
}

/// Payload pushed to [SignalRChatService.onDirectMessageDeleted].
///
/// Direct-chat events carry a `conversationKey` where the group-chat
/// ones carry a `groupId`. The two are deliberately distinct types so a
/// mis-wired handler can't post a private message into a course group.
class DirectMessageDeletedEvent {
  final String conversationKey;
  final int messageId;
  const DirectMessageDeletedEvent({
    required this.conversationKey,
    required this.messageId,
  });
}

/// Payload pushed to [SignalRChatService.onDirectTyping].
class DirectTypingEvent {
  final String conversationKey;
  final int userId;
  final String userRole;
  final String userName;
  final bool typing;
  const DirectTypingEvent({
    required this.conversationKey,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.typing,
  });
}

/// Payload pushed to [SignalRChatService.onDirectMessagesRead].
class DirectMessagesReadEvent {
  final String conversationKey;
  final int readByUserId;
  final String readByRole;
  final int lastReadMessageId;
  final DateTime readAt;
  const DirectMessagesReadEvent({
    required this.conversationKey,
    required this.readByUserId,
    required this.readByRole,
    required this.lastReadMessageId,
    required this.readAt,
  });
}

/// Payload pushed to [SignalRChatService.onConversationBlockChanged].
/// Staff blocked or unblocked the thread — history stays readable, but
/// the composer must disable live rather than letting the learner
/// discover it by failing to send.
class DirectBlockChangedEvent {
  final String conversationKey;
  final bool isBlocked;
  const DirectBlockChangedEvent({
    required this.conversationKey,
    required this.isBlocked,
  });
}

/// Real-time chat transport — wraps a single [HubConnection] for the
/// app's lifetime and brokers the SignalR events as broadcast Streams.
///
/// The service is a singleton: one connection is shared across every
/// chat-room screen, with [joinGroup] / [leaveGroup] gating which
/// room's events the user receives. On auto-reconnect (handled by
/// signalr_netcore), the [_activeGroupId] is re-joined so transient
/// network drops are invisible to the UI.
class SignalRChatService {
  final SessionService _session;

  /// Built lazily inside [connect]. Null when offline or after
  /// [disconnect]. Use [isConnected] to check state.
  HubConnection? _connection;

  /// Room the user is currently inside (between [joinGroup] and
  /// [leaveGroup]). Kept here so we can re-join automatically after a
  /// SignalR auto-reconnect.
  String? _activeGroupId;

  /// Personal-chat thread the user is currently inside (between
  /// [joinConversation] and [leaveConversation]). Tracked separately
  /// from [_activeGroupId] — a learner can have a course group open in
  /// the back stack while sitting in a DM — and re-joined on
  /// auto-reconnect for exactly the same reason.
  String? _activeConversationKey;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _deletedController = StreamController<ChatMessageDeletedEvent>.broadcast();
  final _typingController = StreamController<ChatTypingEvent>.broadcast();
  final _readController = StreamController<ChatMessagesReadEvent>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // ── Direct (1-to-1) chat ────────────────────────────────────────────
  final _directMessageController = StreamController<ChatMessage>.broadcast();
  final _directEditedController = StreamController<ChatMessage>.broadcast();
  final _directInboxController = StreamController<DmConversation>.broadcast();
  final _directDeletedController =
      StreamController<DirectMessageDeletedEvent>.broadcast();
  final _directTypingController =
      StreamController<DirectTypingEvent>.broadcast();
  final _directReadController =
      StreamController<DirectMessagesReadEvent>.broadcast();
  final _directBlockController =
      StreamController<DirectBlockChangedEvent>.broadcast();

  SignalRChatService(this._session);

  /// New messages pushed by the hub (`ReceiveMessage` event).
  Stream<ChatMessage> get onMessage => _messageController.stream;

  /// Server-side message deletions (`MessageDeleted`).
  Stream<ChatMessageDeletedEvent> get onMessageDeleted =>
      _deletedController.stream;

  /// Start / stop typing notifications from the other party
  /// (`UserTyping` / `UserStoppedTyping`).
  Stream<ChatTypingEvent> get onTyping => _typingController.stream;

  /// Read receipts (`MessagesRead`).
  Stream<ChatMessagesReadEvent> get onMessagesRead => _readController.stream;

  /// Generic server errors (`Error` event) — e.g. user tried to send
  /// when `canUserReply` was false.
  Stream<String> get onError => _errorController.stream;

  /// New personal-chat messages (`ReceiveDirectMessage`). Same wire
  /// shape as [onMessage] — the DM rows live in the same table — so
  /// each message's `groupId` carries the conversation key.
  Stream<ChatMessage> get onDirectMessage => _directMessageController.stream;

  /// An author rewrote a message (`DirectMessageEdited`). Carries the
  /// **full updated message** — replace in place by id.
  ///
  /// You receive this for your own edits too, since you're a member of
  /// the thread. Applying it twice is a no-op as long as you match on
  /// id rather than appending.
  Stream<ChatMessage> get onDirectMessageEdited =>
      _directEditedController.stream;

  /// Inbox card refreshes (`DirectInboxUpdated`).
  ///
  /// The one event here that is **not** scoped to a joined SignalR
  /// group: the server addresses it to the user by id, so it arrives
  /// even when the learner is nowhere near the thread. That is what
  /// makes an unread badge move in real time — and why its listener has
  /// to live somewhere long-lived rather than in a per-screen cubit.
  Stream<DmConversation> get onDirectInboxUpdated =>
      _directInboxController.stream;

  /// Personal-chat message deletions (`DirectMessageDeleted`).
  Stream<DirectMessageDeletedEvent> get onDirectMessageDeleted =>
      _directDeletedController.stream;

  /// Typing notifications inside a thread (`DirectUserTyping` /
  /// `DirectUserStoppedTyping`).
  Stream<DirectTypingEvent> get onDirectTyping =>
      _directTypingController.stream;

  /// Personal-chat read receipts (`DirectMessagesRead`).
  Stream<DirectMessagesReadEvent> get onDirectMessagesRead =>
      _directReadController.stream;

  /// Staff blocked / unblocked a thread
  /// (`DirectConversationBlockChanged`).
  Stream<DirectBlockChangedEvent> get onConversationBlockChanged =>
      _directBlockController.stream;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  /// `{BASE_URL}/hubs/ChatHub` — the SignalR endpoint. Sourced from the
  /// same `.env` that drives the REST [ApiClient] so deployments stay
  /// in sync. Path casing matches the backend's `app.MapHub<ChatHub>`
  /// registration; ASP.NET Core endpoint routing is case-insensitive
  /// but the canonical form is `ChatHub`, confirmed against the live
  /// `POST /hubs/ChatHub/negotiate` contract.
  String get _hubUrl {
    final base = dotenv.env['BASE_URL'] ?? '';
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed/hubs/ChatHub';
  }

  /// Build + start the hub connection if one isn't already up. Safe
  /// to call repeatedly; subsequent calls are no-ops when already
  /// connected.
  ///
  /// Throws when there's no chat token cached on [SessionService] —
  /// the caller is responsible for minting one via
  /// `ChatGroupRepository.generateChatToken()` before connecting.
  Future<void> connect() async {
    if (isConnected) {
      debugPrint('$_kChatLogTag connect(): already connected — no-op');
      return;
    }
    final token = _session.chatToken;
    if (token == null || token.isEmpty) {
      debugPrint('$_kChatLogTag connect() ABORTED: no chat token cached');
      throw StateError(
        'SignalRChatService.connect() requires a chat token. '
        'Call ChatGroupRepository.generateChatToken() first.',
      );
    }
    debugPrint(
      '$_kChatLogTag connect() url=$_hubUrl tokenLen=${token.length}',
    );

    final connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _session.chatToken ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Server -> client event wiring. Each handler defensively coerces
    // the args list into a Map (signalr_netcore decodes hub payloads
    // as `Map<dynamic, dynamic>` rather than `Map<String, dynamic>`).
    connection.on('ReceiveMessage', _handleReceiveMessage);
    connection.on('MessageDeleted', _handleMessageDeleted);
    connection.on('UserTyping', _handleUserTyping);
    connection.on('UserStoppedTyping', _handleUserStoppedTyping);
    connection.on('MessagesRead', _handleMessagesRead);
    connection.on('Error', _handleError);

    // Direct (1-to-1) chat. Method names are deliberately distinct
    // from the group-chat set so a mis-wired handler can never leak a
    // private message into a course group.
    connection.on('ReceiveDirectMessage', _handleReceiveDirectMessage);
    connection.on('DirectInboxUpdated', _handleDirectInboxUpdated);
    connection.on('DirectMessageDeleted', _handleDirectMessageDeleted);
    connection.on('DirectMessageEdited', _handleDirectMessageEdited);
    connection.on('DirectUserTyping', _handleDirectUserTyping);
    connection.on('DirectUserStoppedTyping', _handleDirectUserStoppedTyping);
    connection.on('DirectMessagesRead', _handleDirectMessagesRead);
    connection.on(
      'DirectConversationBlockChanged',
      _handleDirectBlockChanged,
    );

    // On automatic reconnect, rejoin the room the user was viewing so
    // they don't have to back-and-re-enter to resume receiving events.
    // Both the group room AND the DM thread are re-joined: miss either
    // and a Wi-Fi flip silently stops delivery to the open screen.
    connection.onreconnected(({connectionId}) async {
      debugPrint(
        '$_kChatLogTag onreconnected connectionId=$connectionId '
        'activeGroup=$_activeGroupId '
        'activeConversation=$_activeConversationKey',
      );
      final active = _activeGroupId;
      if (active != null) {
        try {
          await connection.invoke('JoinGroup', args: [active]);
        } catch (e, st) {
          debugPrint('$_kChatLogTag rejoin failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }
      final activeConversation = _activeConversationKey;
      if (activeConversation != null) {
        try {
          await connection.invoke(
            'JoinConversation',
            args: [activeConversation],
          );
        } catch (e, st) {
          debugPrint('$_kChatLogTag conversation rejoin failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }
    });
    connection.onreconnecting(({error}) {
      debugPrint('$_kChatLogTag onreconnecting error=$error');
    });
    connection.onclose(({error}) {
      debugPrint('$_kChatLogTag onclose error=$error');
    });

    _connection = connection;
    try {
      await connection.start();
      debugPrint(
        '$_kChatLogTag connect() OK state=${connection.state}',
      );
    } catch (e, st) {
      debugPrint('$_kChatLogTag connect() FAILED: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Join the given room. Required before the server starts pushing
  /// `ReceiveMessage` events for it.
  Future<void> joinGroup(String groupId) async {
    _activeGroupId = groupId;
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) {
      debugPrint(
        '$_kChatLogTag joinGroup($groupId) SKIPPED — connection state='
        '${c?.state}',
      );
      return;
    }
    try {
      await c.invoke('JoinGroup', args: [groupId]);
      debugPrint('$_kChatLogTag joinGroup($groupId) OK');
    } catch (e, st) {
      debugPrint('$_kChatLogTag joinGroup($groupId) FAILED: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Leave the given room. Pair with [joinGroup] on chat-screen open
  /// and close so the hub knows which rooms the user is "in".
  Future<void> leaveGroup(String groupId) async {
    if (_activeGroupId == groupId) _activeGroupId = null;
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    try {
      await c.invoke('LeaveGroup', args: [groupId]);
      debugPrint('$_kChatLogTag leaveGroup($groupId) OK');
    } catch (e) {
      debugPrint('$_kChatLogTag leaveGroup($groupId) FAILED: $e');
    }
  }

  /// Send a new message. Only honoured by the server when
  /// `canUserReply` is true on the group; otherwise it'll come back as
  /// an [onError] payload.
  Future<void> sendMessage({
    required String groupId,
    required String message,
    ChatMessageType messageType = ChatMessageType.text,
    String? mediaUrl,
    int? replyToMessageId,
  }) async {
    final c = _connection;
    debugPrint(
      '$_kChatLogTag sendMessage() groupId=$groupId '
      'state=${c?.state} type=${messageType.wireValue} '
      'len=${message.length}',
    );
    if (c == null || c.state != HubConnectionState.Connected) {
      debugPrint(
        '$_kChatLogTag sendMessage() ABORTED — not connected '
        '(state=${c?.state})',
      );
      throw StateError('SignalR is not connected — call connect() first.');
    }
    final payload = {
      'groupId': groupId,
      'message': message,
      'messageType': messageType.wireValue,
      'mediaUrl': mediaUrl,
      'replyToMessageId': replyToMessageId,
    };
    try {
      final result = await c.invoke('SendMessage', args: [payload]);
      debugPrint('$_kChatLogTag sendMessage() OK result=$result');
    } catch (e, st) {
      debugPrint('$_kChatLogTag sendMessage() FAILED: $e');
      debugPrint('$_kChatLogTag payload=$payload');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Clear the unread count by marking everything up to
  /// [lastMessageId] as read.
  Future<void> markMessagesRead({
    required String groupId,
    required int lastMessageId,
  }) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke('MarkMessagesRead', args: [groupId, lastMessageId]);
  }

  /// Notify the other party that the current user has started typing.
  Future<void> startTyping(String groupId) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke('StartTyping', args: [groupId]);
  }

  /// Pair with [startTyping] on the input's debounce/blur.
  Future<void> stopTyping(String groupId) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke('StopTyping', args: [groupId]);
  }

  // ───────────────────────────────────────────────────────────────────
  // Direct (1-to-1) chat — client -> server
  // ───────────────────────────────────────────────────────────────────

  /// Join a personal-chat thread. Required before the server starts
  /// pushing `ReceiveDirectMessage` for it. `DirectInboxUpdated` flows
  /// regardless — it's addressed by user id, not by joined group.
  Future<void> joinConversation(String conversationKey) async {
    _activeConversationKey = conversationKey;
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) {
      debugPrint(
        '$_kChatLogTag joinConversation($conversationKey) SKIPPED — '
        'connection state=${c?.state}',
      );
      return;
    }
    try {
      await c.invoke('JoinConversation', args: [conversationKey]);
      debugPrint('$_kChatLogTag joinConversation($conversationKey) OK');
    } catch (e, st) {
      debugPrint('$_kChatLogTag joinConversation($conversationKey) FAILED: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Pair with [joinConversation] on chat-screen open and close.
  Future<void> leaveConversation(String conversationKey) async {
    if (_activeConversationKey == conversationKey) {
      _activeConversationKey = null;
    }
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    try {
      await c.invoke('LeaveConversation', args: [conversationKey]);
      debugPrint('$_kChatLogTag leaveConversation($conversationKey) OK');
    } catch (e) {
      debugPrint('$_kChatLogTag leaveConversation($conversationKey) FAILED: $e');
    }
  }

  /// Send a personal-chat message.
  ///
  /// When the thread is blocked the server declines the write and emits
  /// an `Error` event — this `invoke` still returns normally. Handle the
  /// refusal on [onError], not with a try/catch here.
  Future<void> sendDirectMessage({
    required String conversationKey,
    required String message,
    ChatMessageType messageType = ChatMessageType.text,
    String? mediaUrl,
    int? replyToMessageId,
  }) async {
    final c = _connection;
    debugPrint(
      '$_kChatLogTag sendDirectMessage() key=$conversationKey '
      'state=${c?.state} type=${messageType.wireValue} '
      'len=${message.length}',
    );
    if (c == null || c.state != HubConnectionState.Connected) {
      debugPrint(
        '$_kChatLogTag sendDirectMessage() ABORTED — not connected '
        '(state=${c?.state})',
      );
      throw StateError('SignalR is not connected — call connect() first.');
    }
    final payload = {
      'conversationKey': conversationKey,
      'message': message,
      'messageType': messageType.wireValue,
      'mediaUrl': mediaUrl,
      'replyToMessageId': replyToMessageId,
    };
    try {
      final result = await c.invoke('SendDirectMessage', args: [payload]);
      debugPrint('$_kChatLogTag sendDirectMessage() OK result=$result');
    } catch (e, st) {
      debugPrint('$_kChatLogTag sendDirectMessage() FAILED: $e');
      debugPrint('$_kChatLogTag payload=$payload');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Clear a thread's unread count up to [lastReadMessageId].
  Future<void> markDirectRead({
    required String conversationKey,
    required int lastReadMessageId,
  }) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke(
      'MarkDirectRead',
      args: [conversationKey, lastReadMessageId],
    );
  }

  /// Notify the other party that the learner has started typing.
  Future<void> startTypingDirect(String conversationKey) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke('StartTypingDirect', args: [conversationKey]);
  }

  /// Pair with [startTypingDirect] on the input's debounce/blur.
  Future<void> stopTypingDirect(String conversationKey) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    await c.invoke('StopTypingDirect', args: [conversationKey]);
  }

  /// Tear down the connection. The streams stay open so widgets can
  /// safely keep subscribing across reconnects.
  Future<void> disconnect() async {
    final c = _connection;
    _connection = null;
    _activeGroupId = null;
    _activeConversationKey = null;
    if (c != null) {
      try {
        await c.stop();
      } catch (_) {
        // Stop can throw if the socket is already gone — safe to drop.
      }
    }
  }

  /// Permanently dispose. Closes every broadcast stream; the service
  /// is unusable afterward. Typically called only on logout.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _deletedController.close();
    await _typingController.close();
    await _readController.close();
    await _errorController.close();
    await _directMessageController.close();
    await _directEditedController.close();
    await _directInboxController.close();
    await _directDeletedController.close();
    await _directTypingController.close();
    await _directReadController.close();
    await _directBlockController.close();
  }

  // ───────────────────────────────────────────────────────────────────
  // Event handlers — coerce dynamic args into typed payloads + push.
  // ───────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _firstMap(List<Object?>? args) {
    if (args == null || args.isEmpty) return null;
    final raw = args.first;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void _handleReceiveMessage(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- ReceiveMessage args=$args');
    final map = _firstMap(args);
    if (map == null) return;
    _messageController.add(ChatMessage.fromJson(map));
  }

  void _handleMessageDeleted(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _deletedController.add(
      ChatMessageDeletedEvent(
        groupId: map['groupId']?.toString() ?? '',
        messageId: (map['messageId'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  void _handleUserTyping(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _typingController.add(
      ChatTypingEvent(
        groupId: map['groupId']?.toString() ?? '',
        userId: (map['userId'] as num?)?.toInt() ?? 0,
        userRole: map['userRole']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        typing: true,
      ),
    );
  }

  void _handleUserStoppedTyping(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _typingController.add(
      ChatTypingEvent(
        groupId: map['groupId']?.toString() ?? '',
        userId: (map['userId'] as num?)?.toInt() ?? 0,
        userRole: map['userRole']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        typing: false,
      ),
    );
  }

  void _handleMessagesRead(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    final readAtRaw = map['readAt']?.toString();
    final readAt = readAtRaw != null && readAtRaw.isNotEmpty
        ? (DateTime.tryParse(readAtRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    _readController.add(
      ChatMessagesReadEvent(
        groupId: map['groupId']?.toString() ?? '',
        readByUserId: (map['readByUserId'] as num?)?.toInt() ?? 0,
        readByRole: map['readByRole']?.toString() ?? '',
        lastReadMessageId:
            (map['lastReadMessageId'] as num?)?.toInt() ?? 0,
        readAt: readAt,
      ),
    );
  }

  void _handleError(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- Error args=$args');
    if (args == null || args.isEmpty) return;
    _errorController.add(args.first?.toString() ?? 'Chat error');
  }

  // ───────────────────────────────────────────────────────────────────
  // Direct (1-to-1) chat — server -> client
  //
  // Every handler goes through [_firstMap] for the same reason the
  // group-chat ones do: signalr_netcore decodes hub payloads as
  // `Map<dynamic, dynamic>`, so a direct cast throws — and only on a
  // real incoming message, which means it would not surface until QA.
  // ───────────────────────────────────────────────────────────────────

  void _handleReceiveDirectMessage(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- ReceiveDirectMessage args=$args');
    final map = _firstMap(args);
    if (map == null) return;
    // Same wire shape as ReceiveMessage; `groupId` holds the
    // conversation key because DMs share the group-chat table.
    _directMessageController.add(ChatMessage.fromJson(map));
  }

  void _handleDirectInboxUpdated(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- DirectInboxUpdated args=$args');
    final map = _firstMap(args);
    if (map == null) return;
    _directInboxController.add(DmConversation.fromJson(map));
  }

  void _handleDirectMessageEdited(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- DirectMessageEdited args=$args');
    final map = _firstMap(args);
    if (map == null) return;
    _directEditedController.add(ChatMessage.fromJson(map));
  }

  void _handleDirectMessageDeleted(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _directDeletedController.add(
      DirectMessageDeletedEvent(
        conversationKey: map['conversationKey']?.toString() ?? '',
        messageId: (map['messageId'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  void _handleDirectUserTyping(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _directTypingController.add(
      DirectTypingEvent(
        conversationKey: map['conversationKey']?.toString() ?? '',
        userId: (map['userId'] as num?)?.toInt() ?? 0,
        userRole: map['userRole']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        typing: true,
      ),
    );
  }

  void _handleDirectUserStoppedTyping(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    _directTypingController.add(
      DirectTypingEvent(
        conversationKey: map['conversationKey']?.toString() ?? '',
        userId: (map['userId'] as num?)?.toInt() ?? 0,
        userRole: map['userRole']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        typing: false,
      ),
    );
  }

  void _handleDirectMessagesRead(List<Object?>? args) {
    final map = _firstMap(args);
    if (map == null) return;
    final readAtRaw = map['readAt']?.toString();
    final readAt = readAtRaw != null && readAtRaw.isNotEmpty
        ? (DateTime.tryParse(readAtRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    _directReadController.add(
      DirectMessagesReadEvent(
        conversationKey: map['conversationKey']?.toString() ?? '',
        readByUserId: (map['readByUserId'] as num?)?.toInt() ?? 0,
        readByRole: map['readByRole']?.toString() ?? '',
        lastReadMessageId: (map['lastReadMessageId'] as num?)?.toInt() ?? 0,
        readAt: readAt,
      ),
    );
  }

  void _handleDirectBlockChanged(List<Object?>? args) {
    debugPrint('$_kChatLogTag <- DirectConversationBlockChanged args=$args');
    final map = _firstMap(args);
    if (map == null) return;
    _directBlockController.add(
      DirectBlockChangedEvent(
        conversationKey: map['conversationKey']?.toString() ?? '',
        isBlocked: map['isBlocked'] as bool? ?? false,
      ),
    );
  }
}
