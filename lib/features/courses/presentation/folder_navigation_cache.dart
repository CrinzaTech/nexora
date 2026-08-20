import 'package:nexora/features/courses/data/models/course_model.dart';

/// In-memory hand-off for `CourseContent` between the module list and
/// [FolderContentPage].
///
/// `go_router` warns when complex objects are passed via `extra` because
/// they can't be serialized for state restoration. We instead push a
/// content tree into this cache keyed by `nodeId`, navigate with that
/// id in the URL, and let the destination route pull the data back out.
///
/// Entries live only while a navigation hop is in flight, so a stale
/// folder id can't accidentally be resurrected by a back-button replay.
class FolderNavigationCache {
  FolderNavigationCache._();

  static final Map<String, CourseContent> _entries = {};

  static void put(CourseContent content) {
    _entries[content.nodeId] = content;
  }

  /// Reads the cached folder for [nodeId] without removing it.
  /// The entry stays alive so go_router can rebuild the route (e.g. after
  /// popping a child screen) without losing the folder data.
  static CourseContent? peek(String nodeId) => _entries[nodeId];

  /// Reads and removes — kept for any call-site that explicitly wants
  /// one-shot semantics.
  static CourseContent? take(String nodeId) => _entries.remove(nodeId);
}
