/// Where in the app the learner tapped into a webinar — the one part of
/// a lead the server cannot see from the account token alone.
///
/// Travels on the detail route as `?from=<wire>`; a route opened without
/// one (a deep link, a future push) reads as [direct].
enum WebinarEntry {
  home('home'),
  list('list'),
  myBookings('my_bookings'),
  room('room'),
  direct('direct');

  final String wire;

  const WebinarEntry(this.wire);

  static WebinarEntry fromWire(String? value) => WebinarEntry.values.firstWhere(
    (e) => e.wire == value,
    orElse: () => WebinarEntry.direct,
  );
}
