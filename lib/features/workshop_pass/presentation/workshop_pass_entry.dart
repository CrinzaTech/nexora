import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';

/// Whether a workshop pass exists for [webinar], answered **without
/// calling the pass API**.
///
/// This mirrors the server's own three checks, so the entry point only
/// appears where the call would have succeeded:
///
///  * it is an in-person workshop — not a streamed, Zoom or Meet webinar
///    (`joinMode`, never `platform`: `platform` names the product for a
///    badge, `joinMode` names what the client has to do);
///  * it is **paid**, read off `isFree` rather than `isPaid` so a paid
///    workshop discounted to zero is correctly treated as free — free
///    workshops issue no pass;
///  * this attendee has bought it. For a paid webinar `isRegistered` is
///    the proof of purchase: the seat is created by the verified payment
///    and by nothing else.
///
/// If any of the three is false the endpoint answers `402` or `409` and
/// there was never a pass to show. The one case worth handling anyway is
/// `402` — a stale local purchase state — which the pass screen routes
/// back to checkout.
bool showsWorkshopPass(WebinarItem webinar) =>
    webinar.isInPerson && !webinar.isFree && webinar.isRegistered;

/// Opens the entry pass for [slug].
///
/// One helper for every entry point — straight after payment, from the
/// workshop detail screen, and from the venue card in the room — so the
/// route and the carried title stay identical wherever the attendee
/// taps.
Future<void> openWorkshopPass(
  BuildContext context, {
  required String slug,
  String? workshopTitle,
}) {
  final query = StringBuffer('slug=${Uri.encodeComponent(slug)}');
  if (workshopTitle != null && workshopTitle.isNotEmpty) {
    query.write('&title=${Uri.encodeComponent(workshopTitle)}');
  }
  return context.push('${AppRoutes.workshopPass}?$query');
}
