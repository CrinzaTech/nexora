part of 'direct_chat_room_cubit.dart';

@freezed
class DirectChatRoomState with _$DirectChatRoomState {
  const factory DirectChatRoomState.initial() = _Initial;
  const factory DirectChatRoomState.loading() = _Loading;

  /// Active thread — full message list + paging metadata + the typing
  /// hint. Messages are stored newest-first (`messages[0]` is the
  /// latest); the UI renders the list with `reverse: true`.
  ///
  /// [isBlocked] lives on the state rather than being passed down from
  /// the route because staff can flip it mid-conversation: the composer
  /// has to disable live off `DirectConversationBlockChanged`, not on
  /// the next screen open.
  const factory DirectChatRoomState.loaded({
    required List<ChatMessage> messages,
    required bool hasMore,
    required int currentPage,
    required bool isLoadingMore,
    required bool isBlocked,
    @Default([]) List<String> typingUserNames,
  }) = _Loaded;

  const factory DirectChatRoomState.error(String message) = _Error;
}
