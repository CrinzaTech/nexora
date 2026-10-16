import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/domain/usecases/news_usecases.dart';
import 'package:nexora/features/news/presentation/bloc/news_home_cubit.dart';

part 'news_detail_state.dart';
part 'news_detail_cubit.freezed.dart';

/// One post, for the detail page. Opened from the panel it already has the
/// post; opened from a push it fetches it, then marks it read.
class NewsDetailCubit extends SafeCubit<NewsDetailState> {
  final GetNewsDetailUseCase getNewsDetailUseCase;
  final NewsHomeCubit homeCubit;

  NewsDetailCubit({required this.getNewsDetailUseCase, required this.homeCubit})
    : super(const NewsDetailState.loading());

  static const String _goneMessage = 'This news is no longer available.';

  /// [initial] skips the fetch — the panel hands over the post it showed.
  /// A null [newsId] is a malformed link and reads as a gone post.
  Future<void> load(int? newsId, {NewsItem? initial}) async {
    if (initial != null) {
      _show(initial);
      return;
    }
    if (newsId == null) {
      emit(const NewsDetailState.error(_goneMessage));
      return;
    }
    emit(const NewsDetailState.loading());
    final result = await getNewsDetailUseCase(newsId);
    result.fold(
      (failure) => emit(NewsDetailState.error(_messageFor(failure))),
      _show,
    );
  }

  void _show(NewsItem item) {
    homeCubit.markRead(item);
    emit(NewsDetailState.loaded(item.copyWith(isRead: true)));
  }

  /// A 404 or a `success: false` carries the server's readable message; a
  /// network blip gets its own wording instead of a misleading "gone".
  static String _messageFor(Failure failure) => switch (failure) {
    ServerFailure(:final message) => message.isEmpty ? _goneMessage : message,
    NetworkFailure(:final message) => message,
    _ => _goneMessage,
  };
}
