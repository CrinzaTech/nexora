import 'dart:async';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/webinar/data/models/webinar_lead_model.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/domain/usecases/get_webinar_detail_usecase.dart';
import 'package:nexora/features/webinar/domain/usecases/record_webinar_visit_usecase.dart';

part 'webinar_detail_state.dart';
part 'webinar_detail_cubit.freezed.dart';

/// Drives the webinar detail screen — one slug, one fetch.
class WebinarDetailCubit extends SafeCubit<WebinarDetailState> {
  final GetWebinarDetailUseCase getWebinarDetailUseCase;
  final RecordWebinarVisitUseCase recordWebinarVisitUseCase;

  WebinarDetailCubit({
    required this.getWebinarDetailUseCase,
    required this.recordWebinarVisitUseCase,
  }) : super(const WebinarDetailState.initial());

  WebinarEntry _entry = WebinarEntry.direct;
  bool _visitRecorded = false;

  /// The screen's fetch — and the one place a visit is recorded, once
  /// per screen. [silentRefresh] deliberately does not: coming back from
  /// checkout or the room is the same visit, not a new lead. [entry] is
  /// remembered from the first call, so the error screen's retry (which
  /// has no route to read it from) still reports where they came from.
  Future<void> load(String slug, {WebinarEntry? entry}) async {
    if (entry != null) _entry = entry;
    await _fetch(slug, showLoading: true);
    // Only for a webinar that actually loaded — a dead slug is not a lead.
    if (state is _Loaded && !_visitRecorded) {
      _visitRecorded = true;
      unawaited(recordWebinarVisitUseCase(slug, _entry));
    }
  }

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
