/// What a tap on a Home "Live classes" card does. Branch on this, never
/// on `isPurchased` — the server may add rules later.
enum HomeLiveAction {
  /// Purchased: open the course on the Content tab with the node
  /// highlighted.
  openContent,

  /// Not purchased: open the course page so the learner can buy first.
  buyCourse,

  /// A value this build doesn't know. Treated as [buyCourse] — never open
  /// content the server did not explicitly say to open.
  unknown;

  static HomeLiveAction parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'opencontent':
        return HomeLiveAction.openContent;
      case 'buycourse':
        return HomeLiveAction.buyCourse;
      default:
        return HomeLiveAction.unknown;
    }
  }
}

/// Where the class is right now — **the one field to branch the card
/// on**. `live` wins over the clock: an educator may start early.
enum HomeLivePhase {
  /// Start time not reached: countdown from `startsInSeconds`.
  upcoming,

  /// Start time reached but the educator is not on air yet.
  waitingForHost,

  /// Broadcasting now.
  live,

  /// The educator went live and then stopped / lost the uplink — they can
  /// resume any moment. Still joinable (the player shows its "host has
  /// paused" waiting screen and resumes on its own).
  paused,

  /// A value this build doesn't know — treated as [upcoming].
  unknown;

  static HomeLivePhase parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'live':
        return HomeLivePhase.live;
      case 'paused':
        return HomeLivePhase.paused;
      case 'waitingforhost':
      case 'waiting_for_host':
      case 'waiting':
        return HomeLivePhase.waitingForHost;
      case 'upcoming':
      case 'scheduled':
        return HomeLivePhase.upcoming;
      default:
        return HomeLivePhase.unknown;
    }
  }
}

/// One course live class in the Home rail, exactly as the server shaped
/// it for this learner. Ended / cancelled / hidden / paid-only-without-
/// purchase never arrive here; the list order (live first, then soonest)
/// is authoritative.
class HomeLiveSessionItem {
  /// StreamApi room id — equals the live-class node's `url` in the
  /// course content tree, the fallback for finding the node if
  /// [nodeId] ever fails to match.
  final String roomId;
  final String title;

  /// `Scheduled` · `Ready` · `Live`.
  final String status;

  /// Drives the LIVE badge. The server already applies a clock backstop
  /// (booked end + 30 min) — trust it, do not re-derive from the clock.
  final bool isLive;

  /// See [HomeLivePhase]. An older server sends none → [HomeLivePhase.unknown],
  /// and the card falls back to [isLive] + the countdown. Status wins over
  /// the clock — there is no push, so the rail shows what the last fetch
  /// said; refreshing is the mechanism.
  final HomeLivePhase phase;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final int durationMin;

  /// Seconds until start at [receivedAt]; 0 once started. Countdowns
  /// run from this plus local elapsed time, never from the device clock
  /// against `scheduledAt`.
  final int startsInSeconds;
  final String? educatorName;
  final int courseId;
  final String? courseName;

  /// Presigned and short-lived — never cached across sessions by URL.
  final String? courseImageUrl;

  /// The live-class node's id in the course tree (`live_…`) — what gets
  /// highlighted.
  final String nodeId;
  final String? nodeName;

  /// Folder ids from the course root down to the node's parent,
  /// outermost first. Empty for a top-level node.
  final List<String> parentNodeIds;
  final bool isPurchased;
  final HomeLiveAction action;

  /// When this payload landed on the device — the countdown's anchor.
  final DateTime receivedAt;

  const HomeLiveSessionItem({
    required this.roomId,
    required this.title,
    required this.status,
    required this.isLive,
    required this.phase,
    required this.scheduledAt,
    required this.endsAt,
    required this.durationMin,
    required this.startsInSeconds,
    required this.educatorName,
    required this.courseId,
    required this.courseName,
    required this.courseImageUrl,
    required this.nodeId,
    required this.nodeName,
    required this.parentNodeIds,
    required this.isPurchased,
    required this.action,
    required this.receivedAt,
  });

  Duration get timeUntilStart {
    final elapsed = DateTime.now().difference(receivedAt);
    final remaining = Duration(seconds: startsInSeconds) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Broadcasting now — [phase] first, [isLive] for an older server.
  bool get isOnAir => phase == HomeLivePhase.live || isLive;

  /// Went live, then stopped — not on air, but not "hasn't started" either.
  bool get isPaused =>
      !isOnAir &&
      (phase == HomeLivePhase.paused || status.toLowerCase() == 'paused');

  /// Start time reached, educator not on air. Also derived locally when
  /// the server sent no phase and the countdown has run out.
  bool get isWaitingForHost =>
      !isOnAir &&
      !isPaused &&
      (phase == HomeLivePhase.waitingForHost ||
          (phase == HomeLivePhase.unknown && timeUntilStart == Duration.zero));

  /// The card's call to action, per the spec's three cases.
  String get ctaLabel {
    if (!isPurchased || action != HomeLiveAction.openContent) {
      return 'Buy course';
    }
    return isOnAir ? 'Join in course' : 'View in course';
  }

  bool get opensContent =>
      action == HomeLiveAction.openContent && isPurchased;

  factory HomeLiveSessionItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    bool asBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    String? asStr(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    DateTime parseUtc(Object? v) =>
        (v == null ? null : DateTime.tryParse(v.toString())?.toLocal()) ??
        DateTime.now();

    final rawParents = json['parentNodeIds'];
    final parents = <String>[];
    if (rawParents is List) {
      for (final p in rawParents) {
        final id = asStr(p);
        if (id != null) parents.add(id);
      }
    }
    final title = asStr(json['title']) ?? asStr(json['nodeName']) ?? 'Live class';
    return HomeLiveSessionItem(
      roomId: asStr(json['roomId']) ?? '',
      title: title,
      status: asStr(json['status']) ?? 'Scheduled',
      isLive: asBool(json['isLive']),
      phase: HomeLivePhase.parse(json['phase']),
      scheduledAt: parseUtc(json['scheduledAtUtc']),
      endsAt: parseUtc(json['endsAtUtc']),
      durationMin: asInt(json['durationMin']),
      startsInSeconds: asInt(json['startsInSeconds']),
      educatorName: asStr(json['educatorName']),
      courseId: asInt(json['courseId']),
      courseName: asStr(json['courseName']),
      courseImageUrl: asStr(json['courseImageUrl']),
      nodeId: asStr(json['nodeId']) ?? '',
      nodeName: asStr(json['nodeName']) ?? title,
      parentNodeIds: parents,
      isPurchased: asBool(json['isPurchased']),
      action: HomeLiveAction.parse(json['action']),
      receivedAt: DateTime.now(),
    );
  }
}

class HomeLiveSessionsPage {
  final List<HomeLiveSessionItem> sessions;
  final int total;
  final int pageNo;
  final int pageSize;
  final bool hasMore;

  /// How many are live right now — the header's "1 live now" pill.
  final int liveCount;
  final DateTime serverTimeUtc;

  const HomeLiveSessionsPage({
    this.sessions = const [],
    this.total = 0,
    this.pageNo = 1,
    this.pageSize = 10,
    this.hasMore = false,
    this.liveCount = 0,
    required this.serverTimeUtc,
  });

  factory HomeLiveSessionsPage.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final raw = json['sessions'] as List<dynamic>? ?? const [];
    return HomeLiveSessionsPage(
      sessions: raw
          .whereType<Map<String, dynamic>>()
          .map(HomeLiveSessionItem.fromJson)
          .toList(growable: false),
      total: asInt(json['total']),
      pageNo: asInt(json['pageNo'], 1),
      pageSize: asInt(json['pageSize'], 10),
      hasMore: json['hasMore'] == true,
      liveCount: asInt(json['liveCount']),
      serverTimeUtc:
          DateTime.tryParse(json['serverTimeUtc']?.toString() ?? '') ??
              DateTime.now().toUtc(),
    );
  }
}
