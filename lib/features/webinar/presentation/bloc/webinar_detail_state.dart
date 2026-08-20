part of 'webinar_detail_cubit.dart';

@freezed
class WebinarDetailState with _$WebinarDetailState {
  const factory WebinarDetailState.initial() = _Initial;
  const factory WebinarDetailState.loading() = _Loading;
  const factory WebinarDetailState.loaded(WebinarDetail webinar) = _Loaded;
  const factory WebinarDetailState.error(String message) = _Error;
}
