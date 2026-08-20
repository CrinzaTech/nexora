/// Data models for the course filter categories endpoint.
///
/// Endpoint: GET /api/v1/course/categories
/// Response shape:
/// ```json
/// {
///   "success": true,
///   "message": "...",
///   "data": {
///     "category": [ { "categoryId": int, "categoryName": String } ],
///     "courseType": [ { "typeId": int, "typeName": String } ]
///   }
/// }
/// ```
library;

class CourseCategory {
  final int categoryId;
  final String categoryName;

  const CourseCategory({
    required this.categoryId,
    required this.categoryName,
  });

  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    return CourseCategory(
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName'] as String? ?? '',
    );
  }
}

class CourseType {
  final int typeId;
  final String typeName;

  const CourseType({
    required this.typeId,
    required this.typeName,
  });

  /// [index] is the position in the API list and is used as [typeId] when
  /// the JSON object does not include a "typeId" field (the server currently
  /// returns only `typeName`).
  factory CourseType.fromJson(Map<String, dynamic> json, {required int index}) {
    return CourseType(
      typeId: (json['typeId'] as num?)?.toInt() ?? index,
      typeName: json['typeName'] as String? ?? '',
    );
  }
}

/// Aggregates both lists returned by the categories endpoint under `data`.
class CourseFilterData {
  final List<CourseCategory> categories;
  final List<CourseType> courseTypes;

  const CourseFilterData({
    required this.categories,
    required this.courseTypes,
  });

  factory CourseFilterData.fromJson(Map<String, dynamic> json) {
    final categoryList = json['category'] as List<dynamic>? ?? const [];
    final typeList = json['courseType'] as List<dynamic>? ?? const [];

    return CourseFilterData(
      categories: categoryList
          .whereType<Map<String, dynamic>>()
          .map(CourseCategory.fromJson)
          .toList(),
      // Use the list index as typeId because the API omits the field:
      // index 0 = "all", 1 = "free", 2 = "paid", etc.
      courseTypes: typeList
          .whereType<Map<String, dynamic>>()
          .toList()
          .asMap()
          .entries
          .map((e) => CourseType.fromJson(e.value, index: e.key))
          .toList(),
    );
  }
}

enum CatalogSortBy {
  all,
  trending,
  newest,
}

extension CatalogSortByExtension on CatalogSortBy {
  String get apiValue {
    switch (this) {
      case CatalogSortBy.all:
        return 'all';
      case CatalogSortBy.trending:
        return 'trending';
      case CatalogSortBy.newest:
        return 'newest';
    }
  }
}

class CatalogFilter {
  final String? searchQuery;
  final int? categoryId;
  final int? tileId;
  final int? courseStatusType;
  final String? courseType;
  final CatalogSortBy? sortBy;

  const CatalogFilter({
    this.searchQuery,
    this.categoryId,
    this.tileId,
    this.courseStatusType,
    this.courseType,
    this.sortBy,
  });
}
