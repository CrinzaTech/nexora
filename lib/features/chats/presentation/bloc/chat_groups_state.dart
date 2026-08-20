part of 'chat_groups_cubit.dart';

@freezed
class ChatGroupsState with _$ChatGroupsState {
  const factory ChatGroupsState.initial() = _Initial;
  const factory ChatGroupsState.loading() = _Loading;
  const factory ChatGroupsState.loaded(List<ChatGroupModel> groups) = _Loaded;
  const factory ChatGroupsState.error(String message) = _Error;
}
