part of 'workshop_pass_cubit.dart';

@freezed
class WorkshopPassState with _$WorkshopPassState {
  const factory WorkshopPassState.initial() = _Initial;

  /// Nothing cached and the fetch is in flight. A pass that *was* cached
  /// never passes through here — it goes straight to [loaded].
  const factory WorkshopPassState.loading() = _Loading;

  /// The ticket. [fromCache] says it came off disk rather than the wire,
  /// which is worth a quiet line on screen but changes nothing about
  /// whether it scans.
  const factory WorkshopPassState.loaded(WorkshopPass pass, bool fromCache) =
      _Loaded;

  /// `402` — they have not bought this workshop. **Not an error**: this
  /// is the state before buying, so it shows a Buy button rather than a
  /// red message.
  const factory WorkshopPassState.needsPurchase(String message) =
      _NeedsPurchase;

  /// `409` / `404` — no pass exists to show: a free or cancelled
  /// workshop, a webinar that is not a workshop at all, or a design the
  /// organiser has to sort out. Worded as information; the server's own
  /// sentence is shown verbatim.
  const factory WorkshopPassState.unavailable(String message) = _Unavailable;

  const factory WorkshopPassState.error(String message) = _Error;
}
