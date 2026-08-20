/// Models for the webinar feature — `GET /api/v1/webinars` (list) and
/// `GET /api/v1/webinars/{slug}` (detail). See WEBINAR_API.md.
///
/// Hand-written rather than Freezed/JSON-serializable to match the rest
/// of this app's data layer, and because every field here is read
/// defensively: a webinar that arrives with one malformed timestamp
/// should still render, not take the whole rail down with it.
library;

/// What "joining" actually means for a webinar.
///
/// **Branch on this, never on `platform`.** `platform` names the product
/// (Zoom, Meet, a workshop) and exists for a badge; this names the thing
/// the client has to *do*, so a meeting platform added later still lands
/// on the code already written for [meeting].
enum WebinarJoinMode {
  /// Streamed by us — lobby, HLS player, in-page chat, recording.
  stream,

  /// Zoom / Google Meet — leave the app entirely for `externalJoinUrl`.
  meeting,

  /// A place, on a day. Show the venue; do **not** auto-launch the map.
  location;

  static WebinarJoinMode parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'meeting':
        return WebinarJoinMode.meeting;
      case 'location':
        return WebinarJoinMode.location;
      default:
        return WebinarJoinMode.stream;
    }
  }
}

/// A webinar as it appears in the dashboard rail.
class WebinarItem {
  /// The id used everywhere — the route key for the detail call. There
  /// is no numeric webinar id on the wire.
  final String slug;

  /// Streaming room id. Informational only; the app never sends it
  /// anywhere (the join flow lives on the web side).
  final String roomId;

  final String title;
  final String? description;

  /// Presigned S3, ~30 minutes. Never persist the URL — cache the bytes
  /// and re-fetch the URL, which is exactly what [CustomNetworkImage]
  /// does via its signature-stripping cache key.
  final String? thumbnailUrl;

  final String? educatorName;

  final DateTime scheduledAtUtc;
  final DateTime endsAtUtc;
  final int durationMin;

  /// `Scheduled` · `Ready` · `Live` · `Ended` · `Cancelled`.
  ///
  /// Display only, and not to be trusted for the LIVE badge — it is a
  /// cached column refreshed by the admin panel's poll, so a finished
  /// webinar can sit at `"Live"` indefinitely. Use [isLive].
  final String status;

  /// Whether the class is live *right now*. Combines [status] with the
  /// server clock, so unlike [status] it cannot get stuck lit.
  final bool isLive;

  /// Seconds until the start, as of [receivedAt]. 0 once the start time
  /// has passed.
  final int startsInSeconds;

  /// The org's own web join page. Null whenever joining is blocked —
  /// deliberately, so no surface can offer a link that would only
  /// reject whoever opened it.
  final String? shareLink;

  /// This learner already registered. A label, not a gate — rejoining
  /// is always allowed. For a **paid** webinar it is also the proof of
  /// purchase: the seat is granted by the payment and by nothing else.
  final bool isRegistered;

  /// `platform` · `zoom` · `google_meet` · `workshop`. Informational —
  /// [joinMode] is what decides behaviour.
  final String platform;

  /// "Crinza Live" · "Zoom" · "Google Meet" · "Workshop" — the badge and
  /// the button label ("Join on Zoom"), written by the server so a new
  /// platform names itself without a client release.
  final String platformName;

  /// What joining does. See [WebinarJoinMode].
  final WebinarJoinMode joinMode;

  /// Not streamed by us — a meeting somewhere else, or a place.
  final bool isExternal;

  /// A price is advertised. **Not** "money was received", and not the
  /// field to branch on: a paid webinar discounted to zero has this true
  /// and [isFree] true as well.
  final bool isPaid;

  /// Nothing to pay — genuinely free, or discounted to zero. **This is
  /// the display and branching decision**, so a zero-priced paid webinar
  /// reads "Free" rather than "Pay 0.00".
  final bool isFree;

  /// What the learner is quoted, in rupees — discount applied and
  /// internet charges already folded in. Null when free. There is no
  /// client-side arithmetic to do, and no tax to add.
  final double? price;

  /// List price, for a strikethrough. Null unless a discount moved it.
  final double? originalPrice;

  /// Local wall-clock instant this payload was parsed.
  ///
  /// The countdown is derived from [startsInSeconds] plus the time
  /// elapsed locally since, never from `scheduledAtUtc` against
  /// `DateTime.now()`. Device clocks are wrong often enough that the
  /// latter shows a class as already finished, or never starting — and
  /// measuring elapsed local time sidesteps the skew arithmetic the API
  /// doc works around with `serverTimeUtc`.
  final DateTime receivedAt;

  const WebinarItem({
    required this.slug,
    required this.roomId,
    required this.title,
    required this.status,
    required this.scheduledAtUtc,
    required this.endsAtUtc,
    required this.durationMin,
    required this.startsInSeconds,
    required this.isLive,
    required this.isRegistered,
    required this.receivedAt,
    this.description,
    this.thumbnailUrl,
    this.educatorName,
    this.shareLink,
    this.platform = 'platform',
    this.platformName = 'Crinza Live',
    this.joinMode = WebinarJoinMode.stream,
    this.isExternal = false,
    this.isPaid = false,
    this.isFree = true,
    this.price,
    this.originalPrice,
  });

  /// Streamed by us: the only mode with a player, a lobby and chat.
  bool get isStream => joinMode == WebinarJoinMode.stream;

  /// Zoom / Meet — opened in the external browser or their app.
  bool get opensExternally => joinMode == WebinarJoinMode.meeting;

  /// In person. The "join link" is a venue.
  bool get isInPerson => joinMode == WebinarJoinMode.location;

  /// How long until the class starts, counted down from the moment the
  /// payload arrived. [Duration.zero] once it has started (or is live).
  Duration get timeUntilStart {
    final elapsed = DateTime.now().difference(receivedAt);
    final remaining = Duration(seconds: startsInSeconds) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// The start time in the device's own timezone, for date/time labels.
  DateTime get scheduledAtLocal => scheduledAtUtc.toLocal();

  /// Whether the class has finished, per the timestamps rather than the
  /// cached [status] column.
  bool get hasEnded => DateTime.now().toUtc().isAfter(endsAtUtc);

  factory WebinarItem.fromJson(Map<String, dynamic> json) {
    final scheduled = parseUtc(json['scheduledAtUtc']);
    final duration = (json['durationMin'] as num?)?.toInt() ?? 0;
    final isPaid = json['isPaid'] as bool? ?? false;
    return WebinarItem(
      slug: json['slug'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: _nonEmpty(json['description']),
      thumbnailUrl: _nonEmpty(json['thumbnailUrl']),
      educatorName: _nonEmpty(json['educatorName']),
      scheduledAtUtc: scheduled ?? DateTime.now().toUtc(),
      // A missing `endsAtUtc` is derived from the duration rather than
      // defaulted to "now", which would mark a future class as ended.
      endsAtUtc:
          parseUtc(json['endsAtUtc']) ??
          (scheduled ?? DateTime.now().toUtc()).add(
            Duration(minutes: duration),
          ),
      durationMin: duration,
      status: json['status'] as String? ?? '',
      isLive: json['isLive'] as bool? ?? false,
      // int on the wire, but tolerate a JSON number arriving as double.
      startsInSeconds: (json['startsInSeconds'] as num?)?.toInt() ?? 0,
      shareLink: _nonEmpty(json['shareLink']),
      isRegistered: json['isRegistered'] as bool? ?? false,
      platform: _nonEmpty(json['platform']) ?? 'platform',
      platformName: _nonEmpty(json['platformName']) ?? 'Crinza Live',
      joinMode: WebinarJoinMode.parse(json['joinMode'] as String?),
      isExternal: json['isExternal'] as bool? ?? false,
      isPaid: isPaid,
      // Absent on a free webinar's payload rather than false — so the
      // fallback is "free unless a price was advertised", never "paid
      // because the field is missing".
      isFree: json['isFree'] as bool? ?? !isPaid,
      price: (json['price'] as num?)?.toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      receivedAt: DateTime.now(),
    );
  }

  /// Parses an ISO-8601 `…Z` timestamp into UTC. Returns null (rather
  /// than throwing) on anything unparseable so one bad row can't fail
  /// the whole list.
  static DateTime? parseUtc(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static String? _nonEmpty(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// One page of `GET /api/v1/webinars`.
class WebinarPage {
  final List<WebinarItem> webinars;
  final int total;
  final int pageNo;
  final int pageSize;
  final bool hasMore;

  /// How many of them are live right now — lets a section header say
  /// "1 live now" without scanning the list.
  final int liveCount;

  const WebinarPage({
    this.webinars = const [],
    this.total = 0,
    this.pageNo = 1,
    this.pageSize = 10,
    this.hasMore = false,
    this.liveCount = 0,
  });

  factory WebinarPage.fromJson(Map<String, dynamic> json) {
    final raw = json['webinars'] as List<dynamic>? ?? const [];
    return WebinarPage(
      webinars: raw
          .whereType<Map<String, dynamic>>()
          .map(WebinarItem.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pageNo: (json['pageNo'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      hasMore: json['hasMore'] as bool? ?? false,
      liveCount: (json['liveCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Why the join door is shut, when it is.
enum WebinarGateState {
  open,
  cancelled,
  ended,
  notFound;

  static WebinarGateState parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'cancelled':
        return WebinarGateState.cancelled;
      case 'ended':
        return WebinarGateState.ended;
      case 'notfound':
      case 'not_found':
        return WebinarGateState.notFound;
      default:
        return WebinarGateState.open;
    }
  }
}

/// `GET /api/v1/webinars/{slug}` — the list item plus org branding and
/// the join gate.
class WebinarDetail extends WebinarItem {
  final String orgCode;
  final String? orgName;

  /// Presigned, same ~30 minute window as the thumbnail.
  final String? orgLogoUrl;

  /// The domain this link belongs to. Only the web surface acts on it
  /// (redirecting a link opened under the wrong institute's branding);
  /// the app opens [shareLink] verbatim, which already carries it.
  final String? canonicalHost;

  final WebinarGateState gateState;

  /// False once cancelled, finished, or the host closed the link. This
  /// is what gates the Join button — and [shareLink] is null whenever
  /// it is false, so there is nothing to open either.
  final bool canJoin;

  /// Written for the learner; display verbatim. Empty when [canJoin].
  final String joinBlockedReason;

  /// Whether the server recognised the account token. [isRegistered] is
  /// only meaningful when this is true.
  final bool isAuthenticated;

  const WebinarDetail({
    required super.slug,
    required super.roomId,
    required super.title,
    required super.status,
    required super.scheduledAtUtc,
    required super.endsAtUtc,
    required super.durationMin,
    required super.startsInSeconds,
    required super.isLive,
    required super.isRegistered,
    required super.receivedAt,
    required this.orgCode,
    required this.gateState,
    required this.canJoin,
    required this.joinBlockedReason,
    required this.isAuthenticated,
    super.description,
    super.thumbnailUrl,
    super.educatorName,
    super.shareLink,
    super.platform,
    super.platformName,
    super.joinMode,
    super.isExternal,
    super.isPaid,
    super.isFree,
    super.price,
    super.originalPrice,
    this.orgName,
    this.orgLogoUrl,
    this.canonicalHost,
  });

  factory WebinarDetail.fromJson(Map<String, dynamic> json) {
    final base = WebinarItem.fromJson(json);
    return WebinarDetail(
      slug: base.slug,
      roomId: base.roomId,
      title: base.title,
      status: base.status,
      scheduledAtUtc: base.scheduledAtUtc,
      endsAtUtc: base.endsAtUtc,
      durationMin: base.durationMin,
      startsInSeconds: base.startsInSeconds,
      isLive: base.isLive,
      isRegistered: base.isRegistered,
      receivedAt: base.receivedAt,
      description: base.description,
      thumbnailUrl: base.thumbnailUrl,
      educatorName: base.educatorName,
      shareLink: base.shareLink,
      platform: base.platform,
      platformName: base.platformName,
      joinMode: base.joinMode,
      isExternal: base.isExternal,
      isPaid: base.isPaid,
      isFree: base.isFree,
      price: base.price,
      originalPrice: base.originalPrice,
      orgCode: json['orgCode'] as String? ?? '',
      orgName: WebinarItem._nonEmpty(json['orgName']),
      orgLogoUrl: WebinarItem._nonEmpty(json['orgLogoUrl']),
      canonicalHost: WebinarItem._nonEmpty(json['canonicalHost']),
      gateState: WebinarGateState.parse(json['gateState'] as String?),
      canJoin: json['canJoin'] as bool? ?? false,
      joinBlockedReason: json['joinBlockedReason'] as String? ?? '',
      isAuthenticated: json['isAuthenticated'] as bool? ?? false,
    );
  }

  /// Whether the Join button should do anything. The app joins natively
  /// (A3), so this is `canJoin` and nothing else — `shareLink` belongs
  /// to the share button beside it.
  bool get isJoinable => canJoin;

  /// The learner must buy this before a seat exists. **Branch on
  /// [isFree], never on `isPaid`** — a paid webinar discounted to zero
  /// is free and behaves exactly like one. [isRegistered] is the proof
  /// of purchase: for a paid webinar the seat is created by the payment
  /// and by nothing else.
  bool get needsPayment => canJoin && !isFree && !isRegistered;
}

/// The lobby/room payload — returned identically by A3 (`join`) and A4
/// (`state`), which is why taking the seat can route straight to the
/// lobby or the player without a second call.
class WebinarSessionState {
  /// `Scheduled` · `Ready` · `Live` · `Ended` · `Cancelled`.
  final String status;

  /// The only thing that decides whether to play. False means stay in
  /// the lobby and keep polling; true means call playback **once**.
  final bool canWatch;

  /// Seconds until the start, as of [receivedAt].
  final int startsInSeconds;

  /// Written by the backend to be shown as-is — "Waiting for the host to
  /// start the webinar.", "The webinar is live.", cancelled, finished.
  /// Never re-word it per status; the server knows which case it is.
  final String message;

  /// `platform` · `zoom` · `google_meet` · `workshop`. For a badge.
  final String platform;

  /// The label to put on the button — "Join on Zoom", "Workshop".
  final String platformName;

  /// **Read this before [canWatch].** `canWatch` is false for a meeting
  /// and for a workshop too, so branching on it first leaves a Zoom or
  /// in-person attendee in a lobby that never opens.
  final WebinarJoinMode joinMode;

  /// The Zoom/Meet link, or the venue's map link. Released **only** to a
  /// registered caller — which is what stops it circulating without
  /// anyone registering — and populated as soon as they are seated, not
  /// at start time, so it can be saved to a calendar days ahead. Null
  /// once cancelled or over.
  final String? externalJoinUrl;

  /// Local wall-clock instant this payload was parsed, so the lobby
  /// countdown ticks off elapsed local time rather than the device
  /// clock. Same reasoning as [WebinarItem.receivedAt].
  final DateTime receivedAt;

  const WebinarSessionState({
    required this.status,
    required this.canWatch,
    required this.startsInSeconds,
    required this.message,
    required this.receivedAt,
    this.platform = 'platform',
    this.platformName = 'Crinza Live',
    this.joinMode = WebinarJoinMode.stream,
    this.externalJoinUrl,
  });

  /// Streamed by us — the only mode with a player, a lobby that unlocks,
  /// chat and a chat socket. Calling playback or hub-token for anything
  /// else returns 409.
  bool get isStream => joinMode == WebinarJoinMode.stream;

  /// Zoom / Meet: leave the app entirely.
  bool get opensExternally => joinMode == WebinarJoinMode.meeting;

  /// A workshop: show the venue as a card. Do **not** auto-launch it —
  /// a meeting link is opened at a moment, a venue is somewhere to go,
  /// and the attendee needs to read it, screenshot it, come back to it.
  bool get isInPerson => joinMode == WebinarJoinMode.location;

  /// Something to open or show, once they are registered.
  bool get hasExternalUrl => (externalJoinUrl?.isNotEmpty ?? false);

  /// Whether a **meeting** link may be opened yet.
  ///
  /// The API releases `externalJoinUrl` the moment someone registers, so
  /// that they can save it to a calendar days ahead — which also means
  /// nothing server-side stops them walking into an empty Zoom room on
  /// Tuesday for a Friday class. This is the client's half of that: the
  /// button stays shut until the scheduled start has actually passed.
  ///
  /// Measured from [timeUntilStart], i.e. the server's own
  /// `startsInSeconds` plus locally-elapsed time — never the device
  /// clock, which on a phone set to the wrong date would otherwise
  /// unlock the link a day early or keep it shut through the whole class.
  ///
  /// **A guardrail, not enforcement.** The URL is in the payload either
  /// way; anyone reading the network tab has it. Holding it back until
  /// the window opens is the server's job, and worth doing there too.
  ///
  /// Deliberately not applied to a workshop's venue: an address is
  /// something you travel to, so hiding it until the start would leave
  /// the attendee unable to plan the journey.
  bool get isJoinWindowOpen => timeUntilStart <= Duration.zero;

  /// True once the class is over, by the cached status column. Only used
  /// to pick an end-of-class screen, never to gate playback — [canWatch]
  /// does that.
  bool get hasEnded {
    final s = status.trim().toLowerCase();
    return s == 'ended' || s == 'cancelled';
  }

  bool get isCancelled => status.trim().toLowerCase() == 'cancelled';

  /// How long until the class starts, counted from when this payload
  /// arrived. [Duration.zero] once it is due.
  Duration get timeUntilStart {
    final elapsed = DateTime.now().difference(receivedAt);
    final remaining = Duration(seconds: startsInSeconds) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory WebinarSessionState.fromJson(Map<String, dynamic> json) {
    return WebinarSessionState(
      status: json['status'] as String? ?? '',
      canWatch: json['canWatch'] as bool? ?? false,
      startsInSeconds: (json['startsInSeconds'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      platform: (json['platform'] as String?)?.trim().isNotEmpty == true
          ? (json['platform'] as String).trim()
          : 'platform',
      platformName:
          (json['platformName'] as String?)?.trim().isNotEmpty == true
          ? (json['platformName'] as String).trim()
          : 'Crinza Live',
      joinMode: WebinarJoinMode.parse(json['joinMode'] as String?),
      externalJoinUrl: WebinarItem._nonEmpty(json['externalJoinUrl']),
      receivedAt: DateTime.now(),
    );
  }
}
