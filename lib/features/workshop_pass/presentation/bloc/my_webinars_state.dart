part of 'my_webinars_cubit.dart';

@freezed
class MyWebinarsState with _$MyWebinarsState {
  const factory MyWebinarsState.initial() = _Initial;
  const factory MyWebinarsState.loading() = _Loading;

  /// [webinars] accumulates across pages; [page] is the most recent
  /// response, and carries `hasMore`, the read-back `pageSize` and the
  /// whole-history `upcomingCount` / `pastCount` the tabs label
  /// themselves with.
  ///
  /// An empty [webinars] with a `total` of 0 is a perfectly normal
  /// answer, not an error: the learner has booked nothing yet.
  const factory MyWebinarsState.loaded(
    List<MyWebinar> webinars,
    MyWebinarPage page,
  ) = _Loaded;

  const factory MyWebinarsState.error(String message) = _Error;
}
