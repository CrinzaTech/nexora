import 'package:dartz/dartz.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_catalog_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_courses_by_category_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_courses_by_tile_usecase.dart';

part 'course_list_state.dart';
part 'course_list_cubit.freezed.dart';

class CourseListCubit extends SafeCubit<CourseListState> {
  final GetCoursesByTileUseCase getCoursesByTileUseCase;
  final GetCoursesByCategoryUseCase getCoursesByCategoryUseCase;
  final GetCourseCatalogUseCase getCourseCatalogUseCase;

  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  List<CourseSummary> _courses = [];
  int? _tileId;
  int? _categoryId;
  int? _courseStatusType;
  CatalogSortBy? _sortBy;
  String? _searchQuery;
  bool? _isPaid;

  CourseListCubit({
    required this.getCoursesByTileUseCase,
    required this.getCoursesByCategoryUseCase,
    required this.getCourseCatalogUseCase,
  }) : super(const CourseListState.initial());

  Future<void> loadByTile(int tileId, {bool? isPaid}) async {
    _tileId = tileId;
    _categoryId = null;
    _courseStatusType = null;
    _sortBy = null;
    _searchQuery = null;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCoursesByTileUseCase(tileId: tileId, isPaid: isPaid, pageNo: 1);
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadByCategory(int categoryId, {bool? isPaid}) async {
    _tileId = null;
    _categoryId = categoryId;
    _courseStatusType = null;
    _sortBy = null;
    _searchQuery = null;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCoursesByCategoryUseCase(categoryId: categoryId, isPaid: isPaid, pageNo: 1);
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadByStatusType(int courseStatusType, {bool? isPaid}) async {
    _tileId = null;
    _categoryId = null;
    _courseStatusType = courseStatusType;
    _sortBy = null;
    _searchQuery = null;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCourseCatalogUseCase(
      courseStatusType: courseStatusType,
      courseType: isPaid == true ? 'paid' : (isPaid == false ? 'free' : null),
      pageNo: 1,
    );
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadBySortBy(CatalogSortBy sortBy, {bool? isPaid}) async {
    _tileId = null;
    _categoryId = null;
    _courseStatusType = null;
    _sortBy = sortBy;
    _searchQuery = null;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCourseCatalogUseCase(
      sortBy: sortBy,
      courseType: isPaid == true ? 'paid' : (isPaid == false ? 'free' : null),
      pageNo: 1,
    );
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadBySearchQuery(String searchQuery, {bool? isPaid}) async {
    _tileId = null;
    _categoryId = null;
    _courseStatusType = null;
    _sortBy = null;
    _searchQuery = searchQuery;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCourseCatalogUseCase(
      searchQuery: searchQuery,
      courseType: isPaid == true ? 'paid' : (isPaid == false ? 'free' : null),
      pageNo: 1,
    );
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadCatalog({bool? isPaid}) async {
    _tileId = null;
    _categoryId = null;
    _courseStatusType = null;
    _sortBy = null;
    _searchQuery = null;
    _isPaid = isPaid;
    _currentPage = 1;
    _courses.clear();
    _hasMoreData = true;
    _isLoadingMore = false;

    emit(const CourseListState.loading());
    final result = await getCourseCatalogUseCase(
      courseType: isPaid == true ? 'paid' : (isPaid == false ? 'free' : null),
      pageNo: 1,
    );
    result.fold(
      (failure) => emit(CourseListState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: 1,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMoreData) {
      return;
    }

    _isLoadingMore = true;
    emit(CourseListState.loaded(
      _courses,
      hasMoreData: _hasMoreData,
      currentPage: _currentPage,
      isLoadingMore: true,
    ));

    final nextPage = _currentPage + 1;
    final Either<Failure, CourseCatalogResponse> result;

    if (_tileId != null) {
      result = await getCoursesByTileUseCase(
        tileId: _tileId!,
        isPaid: _isPaid,
        pageNo: nextPage,
      );
    } else if (_categoryId != null) {
      result = await getCoursesByCategoryUseCase(
        categoryId: _categoryId!,
        isPaid: _isPaid,
        pageNo: nextPage,
      );
    } else if (_courseStatusType != null) {
      result = await getCourseCatalogUseCase(
        courseStatusType: _courseStatusType!,
        courseType: _isPaid == true ? 'paid' : (_isPaid == false ? 'free' : null),
        pageNo: nextPage,
      );
    } else if (_sortBy != null) {
      result = await getCourseCatalogUseCase(
        sortBy: _sortBy!,
        courseType: _isPaid == true ? 'paid' : (_isPaid == false ? 'free' : null),
        pageNo: nextPage,
      );
    } else if (_searchQuery != null) {
      result = await getCourseCatalogUseCase(
        searchQuery: _searchQuery!,
        courseType: _isPaid == true ? 'paid' : (_isPaid == false ? 'free' : null),
        pageNo: nextPage,
      );
    } else {
      result = await getCourseCatalogUseCase(
        courseType: _isPaid == true ? 'paid' : (_isPaid == false ? 'free' : null),
        pageNo: nextPage,
      );
    }

    _isLoadingMore = false;

    result.fold(
      (failure) {
        emit(CourseListState.loaded(
          _courses,
          hasMoreData: _hasMoreData,
          currentPage: _currentPage,
          isLoadingMore: false,
        ));
      },
      (catalogResponse) {
        final newCourses = catalogResponse.courses;
        if (newCourses.isEmpty) {
          _hasMoreData = false;
        } else {
          _currentPage = nextPage;
          _courses.addAll(newCourses);
          if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
            _hasMoreData = false;
          } else {
            _hasMoreData = true;
          }
        }

        emit(CourseListState.loaded(
          List.from(_courses),
          hasMoreData: _hasMoreData,
          currentPage: _currentPage,
          isLoadingMore: false,
        ));
      },
    );
  }

  void reset() => emit(const CourseListState.initial());

  /// Flips the purchased flag for one course after an enrolment, in the
  /// paging buffer as well as the emitted state.
  ///
  /// The buffer write-back is the half that matters. Every other emit in
  /// this cubit rebuilds the list from [_courses], so an update that only
  /// touched the emitted state was silently undone by the next emit —
  /// and on the catalog that comes almost immediately: the scroll
  /// listener fires `loadNextPage` whenever the list is within 200px of
  /// the bottom, which a short list already is. The card flipped back to
  /// its "Buy Now" / "Get Free Access" CTA a beat after the purchase
  /// succeeded, which read as the purchase not registering at all.
  void updatePurchasedStatus(int courseId, bool isPurchased) {
    var changed = false;
    for (var i = 0; i < _courses.length; i++) {
      if (_courses[i].courseId != courseId) continue;
      if (_courses[i].isPurchased == isPurchased) continue;
      _courses[i] = _courses[i].copyWith(isPurchased: isPurchased);
      changed = true;
    }
    if (!changed) return;
    state.maybeWhen(
      orElse: () {},
      loaded: (courses, hasMore, currentPage, isLoadingMore) {
        emit(CourseListState.loaded(
          List.from(_courses),
          hasMoreData: hasMore,
          currentPage: currentPage,
          isLoadingMore: isLoadingMore,
        ));
      },
    );
  }
}
