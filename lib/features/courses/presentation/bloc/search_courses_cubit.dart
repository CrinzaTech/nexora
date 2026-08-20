import 'dart:async';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/courses/data/models/course_model.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_catalog_usecase.dart';

part 'search_courses_state.dart';
part 'search_courses_cubit.freezed.dart';

class SearchCoursesCubit extends SafeCubit<SearchCoursesState> {
  final GetCourseCatalogUseCase getCourseCatalogUseCase;

  /// Debounce timer — cancelled on every new keystroke so we only fire the
  /// API call after the user pauses typing for [_debounce].
  Timer? _debounceTimer;
  static const Duration _debounce = Duration(milliseconds: 300);

  /// Tracks the request currently in flight; used to discard stale results
  /// if a newer query lands while an older one is still resolving.
  int _requestSeq = 0;

  /// Persisted across calls so the home search bar's per-keystroke
  /// `search(query)` call uses the same `isPaid` filter the page was
  /// opened with. Set explicitly via [setIsPaid] or via the optional
  /// `isPaid` argument on [search].
  bool? _isPaid;

  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  List<CourseSummary> _courses = [];
  String _currentQuery = '';

  SearchCoursesCubit({required this.getCourseCatalogUseCase})
      : super(const SearchCoursesState.idle());

  /// Lets the page set / change the paid filter without firing a new
  /// search. Useful when the user toggles a filter and we want the next
  /// keystroke to pick up the new value.
  void setIsPaid(bool? value) {
    _isPaid = value;
  }

  /// Public entry point. Empty/whitespace strings short-circuit to `idle`
  /// (returns home to the normal layout). Anything else schedules a
  /// debounced fetch with the current paid filter (overridable per call).
  void search(String query, {bool? isPaid}) {
    if (isPaid != null) _isPaid = isPaid;
    final trimmed = query.trim();
    _debounceTimer?.cancel();

    if (trimmed.length < 3) {
      _currentQuery = '';
      _courses.clear();
      _currentPage = 1;
      _hasMoreData = true;
      _isLoadingMore = false;
      emit(const SearchCoursesState.idle());
      return;
    }

    if (trimmed != _currentQuery) {
      _currentQuery = trimmed;
      _courses.clear();
      _currentPage = 1;
      _hasMoreData = true;
      _isLoadingMore = false;
    }

    Utils.debugLog(
      'SearchCoursesCubit: queued "$trimmed" (isPaid=$_isPaid)',
    );
    _debounceTimer = Timer(_debounce, () => _fire(trimmed));
  }

  Future<void> _fire(String query) async {
    final mySeq = ++_requestSeq;
    emit(SearchCoursesState.loading(query));
    Utils.debugLog(
      'SearchCoursesCubit: firing "$query" (isPaid=$_isPaid)',
    );
    final result = await getCourseCatalogUseCase(
      searchQuery: query,
      courseType: _isPaid == true ? 'Paid' : (_isPaid == false ? 'Free' : null),
      pageNo: 1,
    );
    if (mySeq != _requestSeq) {
      // A newer query has been issued — drop this stale response.
      return;
    }
    result.fold(
      (failure) => emit(SearchCoursesState.error(failure.message)),
      (catalogResponse) {
        _courses = List.from(catalogResponse.courses);
        _currentPage = 1;
        if (catalogResponse.courses.isEmpty) {
          _hasMoreData = false;
        } else if (catalogResponse.totalPages != null && _currentPage >= catalogResponse.totalPages!) {
          _hasMoreData = false;
        } else {
          _hasMoreData = true;
        }
        emit(SearchCoursesState.loaded(
          query,
          _courses,
          _hasMoreData,
          _currentPage,
          false,
        ));
      },
    );
  }

  Future<void> loadNextPage() async {
    if (_currentQuery.length < 3 || _isLoadingMore || !_hasMoreData) {
      return;
    }

    _isLoadingMore = true;
    emit(SearchCoursesState.loaded(
      _currentQuery,
      _courses,
      _hasMoreData,
      _currentPage,
      true,
    ));

    final nextPage = _currentPage + 1;
    final result = await getCourseCatalogUseCase(
      searchQuery: _currentQuery,
      courseType: _isPaid == true ? 'Paid' : (_isPaid == false ? 'Free' : null),
      pageNo: nextPage,
    );

    _isLoadingMore = false;

    result.fold(
      (failure) {
        emit(SearchCoursesState.loaded(
          _currentQuery,
          _courses,
          _hasMoreData,
          _currentPage,
          false,
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

        emit(SearchCoursesState.loaded(
          _currentQuery,
          List.from(_courses),
          _hasMoreData,
          _currentPage,
          false,
        ));
      },
    );
  }

  void clear() {
    _debounceTimer?.cancel();
    _requestSeq++; // invalidate any in-flight request
    _currentQuery = '';
    _courses.clear();
    _currentPage = 1;
    _hasMoreData = true;
    _isLoadingMore = false;
    emit(const SearchCoursesState.idle());
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
