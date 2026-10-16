import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/domain/repositories/news_repository.dart';

/// Badge count + Home popups. Called on Home open, re-entry and app resume.
class GetNewsHomeUseCase {
  final NewsRepository repository;

  GetNewsHomeUseCase(this.repository);

  Future<Either<Failure, NewsHomeSummary>> call() => repository.getHome();
}

/// One page of the News & Updates panel.
class GetNewsPageUseCase {
  final NewsRepository repository;

  GetNewsPageUseCase(this.repository);

  Future<Either<Failure, NewsPage>> call({
    required int pageNo,
    required int pageSize,
  }) => repository.getNews(pageNo: pageNo, pageSize: pageSize);
}

/// A single post — the push / deep-link target.
class GetNewsDetailUseCase {
  final NewsRepository repository;

  GetNewsDetailUseCase(this.repository);

  Future<Either<Failure, NewsItem>> call(int newsId) =>
      repository.getNewsDetail(newsId);
}

/// Reports the popup dialog's posts so they never pop again.
class MarkNewsPopupShownUseCase {
  final NewsRepository repository;

  MarkNewsPopupShownUseCase(this.repository);

  Future<Either<Failure, void>> call(List<int> newsIds) =>
      repository.markPopupShown(newsIds);
}

class MarkNewsReadUseCase {
  final NewsRepository repository;

  MarkNewsReadUseCase(this.repository);

  Future<Either<Failure, void>> call(int newsId) => repository.markRead(newsId);
}

class MarkAllNewsReadUseCase {
  final NewsRepository repository;

  MarkAllNewsReadUseCase(this.repository);

  Future<Either<Failure, void>> call() => repository.markAllRead();
}
