import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'package:nexora/features/courses/data/models/live_class_models.dart';

/// Grep tag for the live-class hub transport. `[ClassHub]` in
/// `flutter logs` isolates the SignalR conversation.
const String _kTag = '[ClassHub]';

// ─────────────────────────────────────────────────────────────────────
// Typed hub events. The service decodes each raw SignalR payload into
// one of these and pushes it on a single broadcast stream so the cubit
// consumes one ordered feed instead of juggling a dozen subscriptions.
// ─────────────────────────────────────────────────────────────────────

sealed class LiveClassHubEvent {
  const LiveClassHubEvent();
}

class RoomStateEvent extends LiveClassHubEvent {
  final RoomState state;
  const RoomStateEvent(this.state);
}

class ChatMessageEvent extends LiveClassHubEvent {
  final LiveChatMessage message;
  const ChatMessageEvent(this.message);
}

class ChatModeChangedEvent extends LiveClassHubEvent {
  final ChatMode mode;
  const ChatModeChangedEvent(this.mode);
}

class QueuePositionEvent extends LiveClassHubEvent {
  final int position;
  const QueuePositionEvent(this.position);
}

class HandLoweredEvent extends LiveClassHubEvent {
  const HandLoweredEvent();
}

class MicGrantedEvent extends LiveClassHubEvent {
  final String url;
  final String token;
  const MicGrantedEvent({required this.url, required this.token});
}

/// The 5s grant window elapsed without the student going live.
class MicExpiredEvent extends LiveClassHubEvent {
  const MicExpiredEvent();
}

/// The server released the student's mic (educator ended their turn, or
/// a moderation change while they held it).
class MicReleasedEvent extends LiveClassHubEvent {
  const MicReleasedEvent();
}

class NowSpeakingEvent extends LiveClassHubEvent {
  final int studentId;
  final String name;
  const NowSpeakingEvent({required this.studentId, required this.name});
}

class SpeakerEndedEvent extends LiveClassHubEvent {
  const SpeakerEndedEvent();
}

class FlagUpdatedEvent extends LiveClassHubEvent {
  final int studentId;
  final bool chatBlocked;
  final bool micBlocked;
  final bool handBlocked;
  const FlagUpdatedEvent({
    required this.studentId,
    required this.chatBlocked,
    required this.micBlocked,
    required this.handBlocked,
  });
}

class KickedEvent extends LiveClassHubEvent {
  final String reason;
  const KickedEvent(this.reason);
}

class ClassStartedEvent extends LiveClassHubEvent {
  const ClassStartedEvent();
}

class ClassEndedEvent extends LiveClassHubEvent {
  const ClassEndedEvent();
}

/// Covers both `classCancelled` and `classDeleted`.
class ClassCancelledEvent extends LiveClassHubEvent {
  const ClassCancelledEvent();
}

/// Server rejected an action (e.g. SendChat while chat-blocked). Reason
/// examples: `chat_blocked`, `hand_blocked`, `mic_blocked`.
class ActionDeniedEvent extends LiveClassHubEvent {
  final String reason;
  const ActionDeniedEvent(this.reason);
}

/// Emitted by the service itself (not the wire) after an automatic
/// reconnect, so the cubit knows to re-sync from a fresh roomState.
class HubReconnectedEvent extends LiveClassHubEvent {
  const HubReconnectedEvent();
}

/// Wraps a single [HubConnection] to the StreamApi class hub. One
/// instance per live-class page (created/disposed with the page). The
/// StreamApi JWT is passed in — this service never mints it.
class LiveClassHubService {
  HubConnection? _connection;
  String? _roomId;

  /// StreamApi JWT, refreshed by [connect]. Read live by the
  /// accessTokenFactory so a re-fetched token is picked up on reconnect.
  String _accessToken;

  final _eventController = StreamController<LiveClassHubEvent>.broadcast();

  LiveClassHubService({required String accessToken})
    : _accessToken = accessToken;

  Stream<LiveClassHubEvent> get events => _eventController.stream;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  /// `{STREAM_HUB_URL||BASE_URL}/hubs/class`. StreamApi may be proxied
  /// on the app host (BASE_URL) or run on its own host — override with
  /// `STREAM_HUB_URL` in `.env` if the hub is not on BASE_URL.
  String get _hubUrl {
    final base = (dotenv.env['STREAM_HUB_URL']?.isNotEmpty ?? false)
        ? dotenv.env['STREAM_HUB_URL']!
        : (dotenv.env['BASE_URL'] ?? '');
    final trimmed =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed/hubs/class';
  }

  /// Open the connection and `JoinRoom(roomId)`. Safe to call once per
  /// page. [accessToken] refreshes the cached token (e.g. after a
  /// re-mint on resume) before (re)connecting.
  Future<void> connect(String roomId, {String? accessToken}) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      _accessToken = accessToken;
    }
    _roomId = roomId;
    if (isConnected) {
      await _joinRoom();
      return;
    }
    final connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _accessToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Server → client wiring. signalr_netcore decodes payloads as
    // Map<dynamic,dynamic>, so every handler coerces via [_map].
    connection.on('roomState', _onRoomState);
    // The server's chat-push event name wasn't verifiable up front, and
    // SignalR method matching is exact — register the common aliases so
    // whichever the StreamApi hub actually invokes gets handled. The
    // cubit de-dupes by id, so a server sending two of these is harmless.
    connection.on('chatMessage', _onChatMessage);
    connection.on('ReceiveMessage', _onChatMessage);
    connection.on('receiveMessage', _onChatMessage);
    connection.on('messageReceived', _onChatMessage);
    connection.on('newMessage', _onChatMessage);
    connection.on('chatReceived', _onChatMessage);
    connection.on('ReceiveChatMessage', _onChatMessage);
    connection.on('chatModeChanged', _onChatModeChanged);
    connection.on('queuePosition', _onQueuePosition);
    connection.on('handLowered', (_) => _emit(const HandLoweredEvent()));
    connection.on('micGranted', _onMicGranted);
    connection.on('micExpired', (_) => _emit(const MicExpiredEvent()));
    connection.on('micReleased', (_) => _emit(const MicReleasedEvent()));
    connection.on('nowSpeaking', _onNowSpeaking);
    // Same aliasing rationale as chat: the "you are live now" push is the
    // only server signal that ends the connecting state, so accept the
    // plausible spellings rather than hanging on an exact-match miss.
    connection.on('speakerStarted', _onNowSpeaking);
    connection.on('speakingStarted', _onNowSpeaking);
    connection.on('speakerEnded', (_) => _emit(const SpeakerEndedEvent()));
    connection.on('flagUpdated', _onFlagUpdated);
    connection.on('kicked', _onKicked);
    connection.on('classStarted', (_) => _emit(const ClassStartedEvent()));
    connection.on('classEnded', (_) => _emit(const ClassEndedEvent()));
    connection.on('classCancelled', (_) => _emit(const ClassCancelledEvent()));
    connection.on('classDeleted', (_) => _emit(const ClassCancelledEvent()));
    connection.on('actionDenied', _onActionDenied);

    // Groups don't survive an auto-reconnect — rejoin, then tell the
    // cubit to re-sync from a fresh roomState.
    connection.onreconnected(({connectionId}) async {
      debugPrint('$_kTag onreconnected id=$connectionId room=$_roomId');
      await _joinRoom();
      _emit(const HubReconnectedEvent());
    });
    connection.onreconnecting(({error}) =>
        debugPrint('$_kTag onreconnecting error=$error'));
    connection.onclose(({error}) => debugPrint('$_kTag onclose error=$error'));

    _connection = connection;
    debugPrint('$_kTag connecting → $_hubUrl');
    try {
      await connection.start();
      debugPrint('$_kTag connected state=${connection.state}');
      await _joinRoom();
    } catch (e, st) {
      debugPrint('$_kTag connect FAILED for $_hubUrl: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Human-readable connection state for diagnostics/logging.
  String get stateLabel => _connection?.state?.toString() ?? 'null';

  /// The resolved hub URL — surfaced so a misconfigured host is
  /// obvious in logs / error messages.
  String get hubUrl => _hubUrl;

  Future<void> _joinRoom() async {
    final room = _roomId;
    final c = _connection;
    if (room == null || c == null || c.state != HubConnectionState.Connected) {
      return;
    }
    try {
      await c.invoke('JoinRoom', args: [room]);
      debugPrint('$_kTag JoinRoom($room) OK');
    } catch (e) {
      debugPrint('$_kTag JoinRoom($room) FAILED: $e');
    }
  }

  // ── Client → server invokes ──────────────────────────────────────

  Future<void> sendChat(String body) => _invoke('SendChat', [body]);
  Future<void> raiseHand() => _invoke('RaiseHand', const []);
  Future<void> lowerHand() => _invoke('LowerHand', const []);
  Future<void> stopSpeaking() => _invoke('StopSpeaking', const []);
  Future<void> micActivated() => _invoke('MicActivated', const []);

  /// Every hub method is room-scoped: roomId is prepended to [extraArgs]
  /// so callers only pass the trailing args. No-op when the room isn't
  /// joined yet or the socket is down.
  Future<void> _invoke(String method, List<Object> extraArgs) async {
    final room = _roomId;
    final c = _connection;
    if (room == null || c == null || c.state != HubConnectionState.Connected) {
      debugPrint('$_kTag $method SKIPPED — state=${c?.state} room=$room');
      return;
    }
    try {
      await c.invoke(method, args: [room, ...extraArgs]);
    } catch (e) {
      debugPrint('$_kTag $method FAILED: $e');
      rethrow;
    }
  }

  /// Disconnect and release the event stream. The service is unusable
  /// afterwards — one instance per page.
  Future<void> dispose() async {
    final c = _connection;
    _connection = null;
    _roomId = null;
    if (c != null) {
      try {
        await c.stop();
      } catch (_) {}
    }
    await _eventController.close();
  }

  // ── Event decoding ───────────────────────────────────────────────

  void _emit(LiveClassHubEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  Map<String, dynamic>? _map(List<Object?>? args) {
    if (args == null || args.isEmpty) return null;
    final raw = args.first;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// First present key holding a number, across the spellings a hub may
  /// use. Returns null when none of [keys] carries a numeric value.
  int? _int(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v.trim());
        if (p != null) return p;
      }
    }
    return null;
  }

  /// First present key holding a non-empty string.
  String? _str(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// Nth positional argument as an int — for hubs that invoke
  /// `nowSpeaking(123, "Asha")` instead of passing a single object.
  int? _posInt(List<Object?>? args, int index) {
    if (args == null || args.length <= index) return null;
    final v = args[index];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  /// Nth positional argument as a string, ignoring maps/nulls.
  String? _posStr(List<Object?>? args, int index) {
    if (args == null || args.length <= index) return null;
    final v = args[index];
    if (v == null || v is Map || v is List) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  void _onRoomState(List<Object?>? args) {
    final map = _map(args);
    if (map == null) return;
    _emit(RoomStateEvent(RoomState.fromJson(map)));
  }

  void _onChatMessage(List<Object?>? args) {
    // Raw log so we can see EXACTLY what the server pushes (event fires
    // + field names + senderRole) when debugging missing educator msgs.
    debugPrint('$_kTag <- chatMessage raw=$args');
    final map = _map(args);
    if (map == null) return;
    _emit(ChatMessageEvent(LiveChatMessage.fromJson(map)));
  }

  void _onChatModeChanged(List<Object?>? args) {
    final map = _map(args);
    if (map == null) return;
    _emit(ChatModeChangedEvent(ChatMode.fromString(map['mode']?.toString())));
  }

  void _onQueuePosition(List<Object?>? args) {
    final map = _map(args);
    final pos = _int(map, const ['position', 'queuePosition', 'pos', 'index']) ??
        _posInt(args, 0);
    if (pos == null) return;
    _emit(QueuePositionEvent(pos));
  }

  void _onMicGranted(List<Object?>? args) {
    debugPrint('$_kTag <- micGranted raw=$args');
    final map = _map(args);
    final url = _str(map, const [
          'url',
          'serverUrl',
          'wsUrl',
          'livekitUrl',
          'liveKitUrl',
          'host',
        ]) ??
        _posStr(args, 0);
    final token = _str(map, const ['token', 'accessToken', 'jwt']) ??
        _posStr(args, 1);
    if (url == null || token == null) {
      debugPrint('$_kTag micGranted MISSING url/token — ignoring');
      return;
    }
    _emit(MicGrantedEvent(url: url, token: token));
  }

  void _onNowSpeaking(List<Object?>? args) {
    // The student's own "am I live?" transition hangs off this event —
    // log the raw payload so a field-name mismatch is diagnosable from
    // `flutter logs` instead of showing as a stuck "Connecting…".
    debugPrint('$_kTag <- nowSpeaking raw=$args');
    final map = _map(args);
    _emit(
      NowSpeakingEvent(
        // 0 means "the server didn't tell us who" — the cubit treats that
        // as "me" while I'm the one connecting, since only the grant
        // holder can be going live at that moment.
        studentId: _int(map, const [
              'studentId',
              'studentID',
              'userId',
              'appUserId',
              'app_user_id',
              'user_id',
              'id',
            ]) ??
            _posInt(args, 0) ??
            0,
        name: _str(map, const [
              'name',
              'studentName',
              'userName',
              'fullName',
              'displayName',
            ]) ??
            _posStr(args, 1) ??
            '',
      ),
    );
  }

  void _onFlagUpdated(List<Object?>? args) {
    final map = _map(args);
    if (map == null) return;
    _emit(
      FlagUpdatedEvent(
        studentId: _int(map, const [
              'studentId',
              'studentID',
              'userId',
              'appUserId',
              'user_id',
              'id',
            ]) ??
            0,
        chatBlocked: map['chatBlocked'] as bool? ?? false,
        micBlocked: map['micBlocked'] as bool? ?? false,
        handBlocked: map['handBlocked'] as bool? ?? false,
      ),
    );
  }

  void _onKicked(List<Object?>? args) {
    final map = _map(args);
    _emit(KickedEvent(map?['reason']?.toString() ?? ''));
  }

  void _onActionDenied(List<Object?>? args) {
    final map = _map(args);
    _emit(ActionDeniedEvent(map?['reason']?.toString() ?? ''));
  }
}
