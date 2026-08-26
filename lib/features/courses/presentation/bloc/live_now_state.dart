part of 'live_now_cubit.dart';

/// No `loading` or `error` case on purpose: the rail is supplementary and
/// renders nothing whenever there is nothing live, so a failed or pending
/// gather is indistinguishable from "no class on air" — which is exactly
/// what should be on screen either way. Same reasoning as the webinar
/// rail, which stays silent rather than putting an empty-state box on
/// every learner's home screen.
@freezed
class LiveNowState with _$LiveNowState {
  const factory LiveNowState.initial() = _Initial;

  /// Only the classes on air right now, newest schedule first.
  const factory LiveNowState.loaded(List<LiveClassLead> leads) = _Loaded;
}
