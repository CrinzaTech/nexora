import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:nexora/features/chats/domain/usecases/get_chat_groups_usecase.dart';

part 'chat_groups_state.dart';
part 'chat_groups_cubit.freezed.dart';

class ChatGroupsCubit extends SafeCubit<ChatGroupsState> {
  final GetChatGroupsUseCase getChatGroupsUseCase;

  ChatGroupsCubit({required this.getChatGroupsUseCase})
    : super(const ChatGroupsState.initial());

  Future<void> load() async {
    emit(const ChatGroupsState.loading());
    final result = await getChatGroupsUseCase();
    result.fold(
      (failure) => emit(ChatGroupsState.error(failure.message)),
      (groups) => emit(ChatGroupsState.loaded(groups)),
    );
  }

  /// Pull-to-refresh — re-fetches without dropping to a `loading` state, so
  /// the existing list stays on screen while the spinner is shown by the
  /// `RefreshIndicator`.
  Future<void> refresh() async {
    final result = await getChatGroupsUseCase();
    result.fold(
      (failure) => emit(ChatGroupsState.error(failure.message)),
      (groups) => emit(ChatGroupsState.loaded(groups)),
    );
  }
}
