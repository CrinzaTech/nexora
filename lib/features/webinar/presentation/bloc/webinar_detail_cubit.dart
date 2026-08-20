import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/usecases/get_webinar_detail_usecase.dart';

part 'webinar_detail_state.dart';
part 'webinar_detail_cubit.freezed.dart';

/// Drives the webinar detail screen — one slug, one fetch.
class WebinarDetailCubit extends SafeCubit<WebinarDetailState> {
  final GetWebinarDetailUseCase getWebinarDetailUseCase;

  WebinarDetailCubit({required this.getWebinarDetailUseCase})
    : super(const WebinarDetailState.initial());

  Future<void> load(String slug) => _fetch(slug, showLoading: true);

  /// Re-read the gate without blanking the screen. Called when the
  /// learner comes back from the join webview: `isRegistered` flips
  /// there, and a webinar can have gone live (or finished) in the
  /// meantime, which changes what the button should say.
  Future<void> silentRefresh(String slug) => _fetch(slug, showLoading: false);

  Future<void> _fetch(String slug, {required bool showLoading}) async {
    if (slug.trim().isEmpty) {
      emit(const WebinarDetailState.error('This webinar link is not valid.'));
      return;
    }
    if (showLoading) emit(const WebinarDetailState.loading());

    final result = await getWebinarDetailUseCase(slug);
    result.fold((failure) {
      if (showLoading) emit(WebinarDetailState.error(failure.message));
    }, (detail) => emit(WebinarDetailState.loaded(detail)));
  }
}
