/// Single source of truth — every live player targets this exact distance
/// behind the live edge, in milliseconds.
///
/// The same value on every device is what makes all viewers see the SAME
/// moment of the class: HLS players otherwise each pick their own spot in
/// the ~30s playlist window at join time and keep that gap all class.
/// Do not vary it per device, network, or rendition — and do not "fix"
/// drift server-side by shrinking hls_window (that reintroduces the
/// segment-404 starvation bug it was raised to solve).
///
/// ## This is NOT the latency the student sees
///
/// It is measured from the **playlist's live edge** — the end of the newest
/// published segment — not from the educator's camera. Glass-to-glass
/// latency is this value *plus* the pipeline ahead of it: encode, waiting
/// for a 1s segment to close, the playlist write, and the player's fetch.
/// That overhead measures ~2.5–3s on this stack, so:
///
///     student-visible latency ≈ kLiveTargetOffsetMs + ~3s
///
/// 8000 was the first value tried and put the class at 10–11s, a
/// regression from the 6–7s students had before any of this existed —
/// because ExoPlayer's untuned HLS default sits 3 × EXT-X-TARGETDURATION
/// (~3s) behind the edge, and `setMinPlaybackSpeed(0.97)` in the vendored
/// fork means the target is actively *held*, slowing playback down to fall
/// back to it rather than merely starting there.
///
/// ## Why 4000
///
/// Restores ~7s glass-to-glass while keeping one shared number, which is
/// all the sync fix ever needed — it does not care what the offset is,
/// only that every device uses the same one.
///
/// The offset is also the hiccup budget: it is how much already-published
/// content sits between the playhead and the edge, so a network stall
/// shorter than this is invisible and a longer one rebuffers. 4s is four
/// segments of headroom. **If stalls or audio-only fallbacks increase in
/// the field, raise this** — each +1000 costs the student ~1s of latency
/// and buys ~1s of stall tolerance. Below ~3000 the player starts
/// requesting segments the server has not published yet.
///
/// Keep [kLiveTargetOffsetMs] in the crinza_web repo equal to this.
// 8000 -> 5000 -> 6000. Settled at 6000 by measurement, not preference.
//
//   8000: catch-up NEVER engaged (0/20 ticks), zero incidents.
//   5000: catch-up engaged on 15 of 29 ticks, plus one long stall that
//         cost 10s in 12s, forced a quality step down to 480p and needed
//         a realign to recover. It worked — but it had to.
//   6000: midpoint. Enough headroom that the corrections stay idle in
//         normal conditions, which is what "stable" actually means.
//
// Going below this needs the SERVER changes in
// docs/LIVE_CDN_SEGMENT_DELIVERY.md (origin TTFB is still ~0.43s, and
// EXT-X-TARGETDURATION is 2 where it should be 1), not a thinner client
// cushion.
//
// 8000 was set when segment delivery took 1.33s per 1s of content and the
// player could not keep up. With Origin Shield enabled that dropped to
// 0.809s — inside the one-second budget — and a full run held target with
// the catch-up loop never engaging (speed stayed 1.0 throughout, zero
// stalls, zero fallbacks). The large cushion is no longer paying for
// anything.
//
// Prior history, kept because it is easy to misread:
//
// At 4s of cushion the player was measured advancing only ~1600ms per
// 3000ms of real time — it spent half its life waiting for segments. The
// consequences cascaded: stalls -> audio-only fallback -> failed playlist
// checks -> a false "host has paused" screen -> player rebuild -> repeat,
// on a ~45s loop for the whole class.
//
// The cushion IS the tolerance for slow delivery. 4s was below what this
// network can sustain, so it ran dry constantly. 8s costs ~4s of latency
// and buys the headroom to actually keep playing.
//
// Stable at ~10s beats unstable at 6s: at 6s students were getting
// neither the latency nor a watchable class.
const int kLiveTargetOffsetMs = 6000;
