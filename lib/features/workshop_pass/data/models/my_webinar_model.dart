/// `GET /api/v1/workshop-pass/my` — everything this learner booked, past
/// and upcoming. See MY_WEBINARS_API.md.
///
/// The pass endpoints are keyed on a workshop's slug, so without this
/// list a learner can only open a pass while the app happens to be
/// holding that slug: true right after buying, false for ever
/// afterwards. This is what makes a pass findable later.
///
/// A history, not a schedule. Cancelled and long-finished events are in
/// here too, and so is every platform, not only workshops.
library;

/// One booked event. De-duplicated server-side to one row per webinar,
/// so a paid workshop the learner also registered for appears once.
class MyWebinar {
  /// Stable list key.
  final int webinarId;

  /// **What every pass call takes.**
  final String slug;

  final String title;

  /// Already presigned, and short-lived — never persist the URL itself.
  final String? thumbnailUrl;

  final String? educatorName;

  final DateTime scheduledAtUtc;
  final DateTime endsAtUtc;
  final int durationMin;

  /// `workshop` · `zoom` · `google_meet` · `platform`.
  final String platform;

  /// `Workshop` · `Zoom` · `Google Meet` · `Crinza Live` — written by the
  /// server so a new platform names itself without a client release.
  final String platformName;

  /// In person. The pass fields below only mean anything when true.
  final bool isWorkshop;

  /// `upcoming` · `live` · `past` · `cancelled`.
  ///
  /// **Computed from the clock server-side, not read off a stored
  /// status.** A finished event can sit at `Live` in the database until
  /// something polls it, and a history claiming last month is live now
  /// is worse than one that says nothing. Trusted over any comparison
  /// this client could make.
  final String state;

  final bool isCancelled;

  /// Negative once the event has begun.
  final int startsInSeconds;

  /// The event charges. **Not** "this learner paid" — see [hasPurchased].
  final bool isPaid;

  /// This learner bought a ticket. False means they registered free.
  final bool hasPurchased;

  /// Venue link for a workshop, meeting URL otherwise.
  final String? venueOrJoinUrl;

  /// Workshop only. A bare URL reduced to its host, for a label.
  final String? venueName;

  /// A pass exists. Only ever true for a **paid workshop they bought**,
  /// which is why this — and never [isWorkshop] — gates the pass button:
  /// a free workshop, or one they registered for without buying, has no
  /// pass and the pass endpoint answers 402 or 409.
  final bool hasPass;

  /// Null until they first open the pass, which is what issues the
  /// number.
  final String? passNo;

  /// Did they turn up.
  ///
  /// **Nullable on purpose, and null is not false.** For a Zoom or Meet
  /// webinar the meeting happens somewhere we cannot observe, so there
  /// is genuinely no answer — and a workshop sold without the managed
  /// door reports the same, because passes were issued but nobody was
  /// appointed to scan them. Reporting "did not attend" there would tell
  /// somebody who did attend that they missed it.
  final bool? attended;

  /// `door_scan` · `joined_room` · `unknown`. Only the first two make
  /// [attended] meaningful.
  final String attendedSource;

  final DateTime? checkedInAtUtc;
  final String? checkedInBy;

  /// Absolute URL for the pass. Composed server-side so the eligibility
  /// rule lives in one place; null when there is no pass.
  final String? passUrl;

  /// Local wall-clock instant this payload was parsed.
  ///
  /// The countdown is derived from [startsInSeconds] plus the time
  /// elapsed locally since, never from [scheduledAtUtc] against
  /// `DateTime.now()`. Device clocks are wrong often enough that the
  /// latter shows an event as already finished, or never starting — and
  /// measuring elapsed local time sidesteps the skew arithmetic the API
  /// doc works around with `serverTimeUtc`, exactly as the webinar list
  /// already does.
  final DateTime receivedAt;

  const MyWebinar({
    required this.webinarId,
    required this.slug,
    required this.title,
    required this.scheduledAtUtc,
    required this.endsAtUtc,
    required this.durationMin,
    required this.platform,
    required this.platformName,
    required this.isWorkshop,
    required this.state,
    required this.isCancelled,
    required this.startsInSeconds,
    required this.isPaid,
    required this.hasPurchased,
    required this.hasPass,
    required this.attendedSource,
    required this.receivedAt,
    this.thumbnailUrl,
    this.educatorName,
    this.venueOrJoinUrl,
    this.venueName,
    this.passNo,
    this.attended,
    this.checkedInAtUtc,
    this.checkedInBy,
    this.passUrl,
  });

  bool get isPast => state == 'past';
  bool get isUpcoming => state == 'upcoming';
  bool get isLive => state == 'live';

  /// In person. Drives the Directions button rather than a Join button.
  bool get isVenue => platform == 'workshop';

  /// Something to open, once there is one.
  bool get hasJoinLink => (venueOrJoinUrl?.trim().isNotEmpty ?? false);

  /// The start time in the device's own zone, for date labels.
  DateTime get scheduledAtLocal => scheduledAtUtc.toLocal();

  /// How long until it starts, counted from when the payload arrived.
  /// [Duration.zero] once it is due.
  Duration get timeUntilStart {
    final remaining =
        Duration(seconds: startsInSeconds) -
        DateTime.now().difference(receivedAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory MyWebinar.fromJson(Map<String, dynamic> json) {
    final scheduled = _parseUtc(json['scheduledAtUtc']);
    final duration = (json['durationMin'] as num?)?.toInt() ?? 0;
    return MyWebinar(
      webinarId: (json['webinarId'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: _nonEmpty(json['thumbnailUrl']),
      educatorName: _nonEmpty(json['educatorName']),
      scheduledAtUtc: scheduled ?? DateTime.now().toUtc(),
      // A missing end is derived from the duration rather than defaulted
      // to now, which would mark a future event as finished.
      endsAtUtc:
          _parseUtc(json['endsAtUtc']) ??
          (scheduled ?? DateTime.now().toUtc()).add(
            Duration(minutes: duration),
          ),
      durationMin: duration,
      platform: _nonEmpty(json['platform']) ?? 'platform',
      platformName: _nonEmpty(json['platformName']) ?? 'Crinza Live',
      isWorkshop: json['isWorkshop'] as bool? ?? false,
      state: _nonEmpty(json['state']) ?? 'upcoming',
      isCancelled: json['isCancelled'] as bool? ?? false,
      startsInSeconds: (json['startsInSeconds'] as num?)?.toInt() ?? 0,
      isPaid: json['isPaid'] as bool? ?? false,
      hasPurchased: json['hasPurchased'] as bool? ?? false,
      venueOrJoinUrl: _nonEmpty(json['venueOrJoinUrl']),
      venueName: _nonEmpty(json['venueName']),
      hasPass: json['hasPass'] as bool? ?? false,
      passNo: _nonEmpty(json['passNo']),
      // Left null when absent. **Never `?? false`** — that is the whole
      // point of the field being nullable.
      attended: json['attended'] as bool?,
      attendedSource: _nonEmpty(json['attendedSource']) ?? 'unknown',
      checkedInAtUtc: _parseUtc(json['checkedInAtUtc']),
      checkedInBy: _nonEmpty(json['checkedInBy']),
      passUrl: _nonEmpty(json['passUrl']),
      receivedAt: DateTime.now(),
    );
  }

  static DateTime? _parseUtc(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static String? _nonEmpty(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// One page of `GET /api/v1/workshop-pass/my`.
class MyWebinarPage {
  final List<MyWebinar> webinars;
  final int total;
  final int pageNo;

  /// **Read back, not assumed.** The server clamps to 1..50, so asking
  /// for 500 quietly returns 50.
  final int pageSize;

  final bool hasMore;

  /// Totals across the whole history, not this page — so the tab labels
  /// are right on page 1 and stay right while paging.
  final int upcomingCount;
  final int pastCount;

  const MyWebinarPage({
    this.webinars = const [],
    this.total = 0,
    this.pageNo = 1,
    this.pageSize = 20,
    this.hasMore = false,
    this.upcomingCount = 0,
    this.pastCount = 0,
  });

  factory MyWebinarPage.fromJson(Map<String, dynamic> json) {
    final raw = json['webinars'] as List<dynamic>? ?? const [];
    return MyWebinarPage(
      webinars: raw
          .whereType<Map<String, dynamic>>()
          .map(MyWebinar.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pageNo: (json['pageNo'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
      upcomingCount: (json['upcomingCount'] as num?)?.toInt() ?? 0,
      pastCount: (json['pastCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What to say about attendance.
///
/// The one rule worth enforcing in a single place: **null is "Not
/// recorded", never "Missed".**
enum AttendanceLabel {
  attended('Attended'),
  didNotAttend('Did not attend'),
  notRecorded('Not recorded');

  final String text;
  const AttendanceLabel(this.text);

  static AttendanceLabel of(MyWebinar webinar) => switch (webinar.attended) {
    true => AttendanceLabel.attended,
    false => AttendanceLabel.didNotAttend,
    null => AttendanceLabel.notRecorded,
  };
}
