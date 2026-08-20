part of 'chat_room_cubit.dart';

@freezed
class ChatRoomState with _$ChatRoomState {
  const factory ChatRoomState.initial() = _Initial;
  const factory ChatRoomState.loading() = _Loading;

  /// Active room — full message list + paging metadata + the typing
  /// hint. Messages are stored newest-first (`messages[0]` is the
  /// latest); the UI renders the list with `reverse: true`.
  const factory ChatRoomState.loaded({
    required List<ChatMessage> messages,
    required bool hasMore,
    required int currentPage,
    required bool isLoadingMore,
    // @Default(<String>[]) List<String> typingUserNames,
    @Default([]) List<String> typingUserNames,
  }) = _Loaded;

  const factory ChatRoomState.error(String message) = _Error;
}
