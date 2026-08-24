import 'dart:convert';
import 'dart:typed_data';

/// `GET /api/v1/workshop-pass/{slug}` — the entry ticket for a paid
/// in-person workshop. See WORKSHOP_PASS_API.md.
///
/// **A pass is not a certificate.** A certificate is earned by finishing
/// a course and is something you download; a pass is bought, exists from
/// the moment the payment verifies, and is something you *hold up at a
/// door*. So the primary action is showing it on screen and saving is
/// secondary — which is why the payload carries rendered [html] rather
/// than only a PDF.
///
/// Nothing here identifies the attendee on the wire: the workshop is
/// named by its [publicSlug][WorkshopPass] and the user comes from the
/// JWT, so there is no field an attendee could edit to reach somebody
/// else's pass.
///
/// Hand-written, and round-trippable through [toJson], because the whole
/// object is cached to disk: the pass has to open in a queue, indoors,
/// with no signal.
class WorkshopPass {
  /// The workshop. Useful as a list key.
  final int webinarId;

  final String workshopTitle;

  /// **Already formatted in the workshop's own timezone.** Print as-is —
  /// re-deriving these from [scheduledAtUtc] in the device's zone is how
  /// a ticket ends up naming yesterday for someone travelling.
  final String workshopDate;
  final String workshopTime;

  /// The raw instant behind [workshopDate] / [workshopTime], for
  /// anything that needs arithmetic rather than a label.
  final DateTime scheduledAtUtc;

  /// What is printed on the ticket. The organiser usually stores a maps
  /// *link*, and a bare URL helps nobody standing outside a building, so
  /// the server reduces one to its host here and hands the full link
  /// over as [venueUrl]. A typed-out address arrives verbatim.
  final String? venueName;

  /// The organiser's link — put a Directions button behind it.
  final String? venueUrl;

  final String attendeeName;

  /// Printed on the ticket. **Read this out when a scan fails**, which
  /// is why it is repeated outside the artwork.
  final String passNo;

  /// First time this pass was fetched — fetching is what issues it.
  final DateTime issuedAt;

  /// True once venue staff have scanned them in.
  final bool isCheckedIn;

  /// A `data:` URI PNG, self-contained — never a URL, which is what lets
  /// the pass work offline. Empty string server-side when QR rendering
  /// failed; normalised to null here.
  final String? qrImage;

  /// The design. Only needed if the app themes around it.
  final String templateCode;
  final String layoutCode;

  /// **A complete standalone HTML document** — doctype, inlined CSS, the
  /// lot, with nothing fetched from our servers except Google Fonts.
  /// Load it with `loadHtmlString`; never inject it into a page of our
  /// own, and never rebuild the ticket natively from the raw fields —
  /// the organiser's preview, this screen and the PDF are one shared
  /// partial precisely so they cannot drift.
  final String html;

  /// Natural size of [html] in CSS px (720 × 340). The document scales
  /// itself to whatever width it is given, so all the UI owes it is the
  /// right *shape* — an AspectRatio, never a fixed height.
  final int canvasWidth;
  final int canvasHeight;

  /// Absolute URL for the save action. Use it rather than composing one.
  final String downloadUrl;

  const WorkshopPass({
    required this.webinarId,
    required this.workshopTitle,
    required this.workshopDate,
    required this.workshopTime,
    required this.scheduledAtUtc,
    required this.attendeeName,
    required this.passNo,
    required this.issuedAt,
    required this.isCheckedIn,
    required this.templateCode,
    required this.layoutCode,
    required this.html,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.downloadUrl,
    this.venueName,
    this.venueUrl,
    this.qrImage,
  });

  /// The QR bytes, decoded out of the `data:` URI. Null when there is no
  /// QR — the pass number is still printed and staff can look that up,
  /// so this is a degraded pass rather than a broken one.
  Uint8List? get qrBytes {
    final uri = qrImage;
    if (uri == null || uri.isEmpty) return null;
    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(uri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  /// Whether there is artwork to render at all. False only if the server
  /// could not build the document, in which case the screen falls back
  /// to the raw fields.
  bool get hasArtwork => html.trim().isNotEmpty;

  /// Shape of the ticket, for the AspectRatio the WebView sits in.
  /// Falls back to the documented 720×340 if either side arrives as 0,
  /// which would otherwise divide by zero in the layout.
  double get aspectRatio {
    if (canvasWidth <= 0 || canvasHeight <= 0) return 720 / 340;
    return canvasWidth / canvasHeight;
  }

  /// Something to put behind a Directions button.
  bool get hasVenueLink => (venueUrl?.trim().isNotEmpty ?? false);

  factory WorkshopPass.fromJson(Map<String, dynamic> json) {
    return WorkshopPass(
      webinarId: (json['webinarId'] as num?)?.toInt() ?? 0,
      workshopTitle: json['workshopTitle'] as String? ?? '',
      workshopDate: json['workshopDate'] as String? ?? '',
      workshopTime: json['workshopTime'] as String? ?? '',
      scheduledAtUtc: _parseDate(json['scheduledAtUtc']) ?? DateTime.now(),
      venueName: _nonEmpty(json['venueName']),
      venueUrl: _nonEmpty(json['venueUrl']),
      attendeeName: json['attendeeName'] as String? ?? '',
      passNo: json['passNo'] as String? ?? '',
      issuedAt: _parseDate(json['issuedAt']) ?? DateTime.now(),
      isCheckedIn: json['isCheckedIn'] as bool? ?? false,
      // Empty string when QR rendering failed server-side; treated as
      // absent so every caller has one thing to check instead of two.
      qrImage: _nonEmpty(json['qrImage']),
      templateCode: json['templateCode'] as String? ?? '',
      layoutCode: json['layoutCode'] as String? ?? '',
      html: json['html'] as String? ?? '',
      canvasWidth: (json['canvasWidth'] as num?)?.toInt() ?? 720,
      canvasHeight: (json['canvasHeight'] as num?)?.toInt() ?? 340,
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }

  /// The payload as it came off the wire, so the cache can hand it
  /// straight back to [fromJson]. Timestamps go out in ISO-8601 for the
  /// same reason.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'webinarId': webinarId,
    'workshopTitle': workshopTitle,
    'workshopDate': workshopDate,
    'workshopTime': workshopTime,
    'scheduledAtUtc': scheduledAtUtc.toIso8601String(),
    'venueName': venueName,
    'venueUrl': venueUrl,
    'attendeeName': attendeeName,
    'passNo': passNo,
    'issuedAt': issuedAt.toIso8601String(),
    'isCheckedIn': isCheckedIn,
    'qrImage': qrImage,
    'templateCode': templateCode,
    'layoutCode': layoutCode,
    'html': html,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'downloadUrl': downloadUrl,
  };

  /// Tolerant date read — a malformed timestamp should cost a label, not
  /// the whole pass.
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static String? _nonEmpty(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// A pass PDF that has been fetched and written to disk.
///
/// The card is 720 × 340 pt, so it prints as a ticket rather than a
/// ticket marooned on an A4 sheet — and is typically 40–120 KB, much
/// smaller than a certificate.
class DownloadedPass {
  /// Absolute path inside the app's documents directory — not the cache
  /// directory, which the OS may clear at any time while the attendee
  /// reasonably expects a saved ticket to survive until the event.
  final String path;

  final String passNo;

  /// The workshop this belongs to — titles the preview screen and the
  /// share sheet.
  final String workshopTitle;

  const DownloadedPass({
    required this.path,
    required this.passNo,
    required this.workshopTitle,
  });
}
