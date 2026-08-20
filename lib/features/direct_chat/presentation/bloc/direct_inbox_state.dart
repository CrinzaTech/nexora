part of 'direct_inbox_cubit.dart';

@freezed
class DirectInboxState with _$DirectInboxState {
  const factory DirectInboxState.initial() = _Initial;
  const factory DirectInboxState.loading() = _Loading;

  /// The learner's threads plus the staff directory they were resolved
  /// against. Both travel together because the inbox screen needs the
  /// directory to answer two questions: "is there anyone left to start
  /// a thread with?" and "is there exactly one, so we can skip the
  /// list entirely?".
  const factory DirectInboxState.loaded({
    required List<DmConversation> conversations,
    required List<DmDirectoryEntry> directory,
  }) = _Loaded;

  const factory DirectInboxState.error(String message) = _Error;
}
