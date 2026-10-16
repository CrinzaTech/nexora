import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';

/// News & Updates — what an educator posted for this learner's org.
abstract class NewsRepository {
  /// Badge count + the posts to pop up on Home.
  Future<Either<Failure, NewsHomeSummary>> getHome();

  /// One page of the panel, newest first.
  Future<Either<Failure, NewsPage>> getNews({
    required int pageNo,
    required int pageSize,
  });

  /// One post. A gone post fails with the server's own "This news is no
  /// longer available." as the message.
  Future<Either<Failure, NewsItem>> getNewsDetail(int newsId);

  /// Every id the popup dialog showed, in one call.
  Future<Either<Failure, void>> markPopupShown(List<int> newsIds);

  Future<Either<Failure, void>> markRead(int newsId);

  Future<Either<Failure, void>> markAllRead();
}
