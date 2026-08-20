import 'package:intl/intl.dart';

import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';

/// Shared date / countdown formatting for the webinar screens, so the
/// rail card and the detail header never disagree about how a schedule
/// reads.
class WebinarFormatting {
  WebinarFormatting._();

  /// "Mon, 24 Aug · 8:00 PM", in the device's own timezone. The API
  /// speaks UTC throughout; a learner does not.
  static String schedule(WebinarItem webinar) {
    final local = webinar.scheduledAtLocal;
    return '${DateFormat('EEE, d MMM').format(local)} · '
        '${DateFormat('h:mm a').format(local)}';
  }

  /// Just the clock time — "8:00 PM".
  static String time(WebinarItem webinar) =>
      DateFormat('h:mm a').format(webinar.scheduledAtLocal);

  /// "90 min" / "1h 30m".
  static String duration(WebinarItem webinar) {
    final minutes = webinar.durationMin;
    if (minutes <= 0) return '';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  /// A compact countdown — "2d 4h", "4h 12m", "12m 30s", "Starting soon".
  ///
  /// Days and hours are shown as two units so a distant class reads at a
  /// glance; only inside the last hour do seconds appear, where they are
  /// the part that actually moves.
  static String countdown(Duration remaining) {
    if (remaining <= Duration.zero) return 'Starting soon';

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// "₹ 918" — the same rupee formatting the course screens use, so a
  /// webinar price and a course price never read differently.
  static String rupees(double amount) => '₹ ${Utils.formatPrice(amount)}';

  /// What the seat costs, as the learner should see it.
  ///
  /// **Driven by `isFree`, not `isPaid`.** A paid webinar discounted to
  /// zero is free and must read "Free" rather than "₹ 0" — and a webinar
  /// that claims a price but ships none is treated as free too, since
  /// there is nothing to charge.
  static String price(WebinarItem webinar) {
    final amount = webinar.price;
    if (webinar.isFree || amount == null || amount <= 0) return 'Free';
    return rupees(amount);
  }

  /// How the start is described on a card: the live badge takes over
  /// when it is live, a countdown inside 24 hours, otherwise the date.
  static String startLabel(WebinarItem webinar) {
    if (webinar.isLive) return 'Live now';
    final remaining = webinar.timeUntilStart;
    if (remaining == Duration.zero) return 'Starting soon';
    if (remaining.inHours < 24) return 'Starts in ${countdown(remaining)}';
    return schedule(webinar);
  }
}
