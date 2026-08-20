# Audit: YouTube Video Quality Selection Missing

**Status:** Root cause confirmed. **Option A implemented** in
[video_player_page.dart](../lib/features/courses/presentation/pages/video_player_page.dart) —
see "Option A implementation" below. Options B and C remain open for future work.

## Summary

Users cannot change YouTube video quality because the app doesn't use YouTube's
native player (which has a built-in gear-icon quality selector). It uses
`pod_player`, which extracts raw stream URLs via `youtube_explode_dart` and
plays them through Flutter's native `video_player` + Material UI. There is no
YouTube chrome at all in this architecture, so there's no quality selector to
find — and no custom one has been built to replace it.

## Where this lives

- **[lib/features/courses/presentation/pages/video_player_page.dart](../lib/features/courses/presentation/pages/video_player_page.dart)**
  is the only file implementing video playback (YouTube and otherwise).
  - `_isYoutubeUrl()` (~L165-170) matches `youtube.com`, `youtu.be`,
    `youtube-nocookie.com` hosts.
  - Controller setup (~L98-116):
    ```dart
    if (_isYoutubeUrl(url)) {
      playFrom = PlayVideoFrom.youtube(url);
    }
    final controller = PodPlayerController(
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: true,
        videoQualityPriority: [1080, 720, 480, 360],
      ),
      playVideoFrom: playFrom,
    );
    ```
  - Player widget (~L364-406): `PodVideoPlayer` with `backgroundColor`,
    `matchFrameAspectRatioToVideo: true`, `alwaysShowProgressBar: false`, a
    custom `PodProgressBarConfig`, and an `onToggleFullScreen` callback. No
    `showControls`/`playerParams`/webview params exist — this isn't an
    iframe/webview player, so those wouldn't apply anyway.
  - `_MovingWatermark` overlay (~L249-285, 426-533) — animated,
    `opacity: 0.4`, wrapped in `IgnorePointer`. Checked and **ruled out** as a
    cause; it's purely cosmetic anti-piracy branding and doesn't intercept
    touches or hide controls.
- **pubspec.yaml:70** — `pod_player: ^0.2.2` (direct dependency, does the
  actual YouTube playback).
- **pubspec.yaml:104** — `webview_flutter: 4.13.1` present but **unused** for
  the YouTube path.
- **pubspec.lock:1837-1840** — `youtube_explode_dart` is a *transitive*
  dependency pulled in by `pod_player`, not something the app calls directly.

## Why `videoQualityPriority` doesn't help

`videoQualityPriority: [1080, 720, 480, 360]` looks like a user-facing
setting but is actually an **internal auto-selection fallback list** — it's
never surfaced in any UI. Inside `pod_player` internals:

- `pod_player-0.2.2/lib/src/utils/video_apis.dart:123-166` —
  `getYoutubeVideoQualityUrls()` calls
  `yt.videos.streamsClient.getManifest(...)` and only reads from
  `manifest.muxed` (combined audio+video streams).
- `pod_player-0.2.2/lib/src/pod_getx_video_controller.dart:114-133` — walks
  `videoQualityPriority` top-down and picks the first resolution present in
  the muxed manifest. Entirely internal; never exposed to the user.

**The real constraint:** YouTube rarely publishes muxed streams above ~720p —
1080p+ only exists as separate video-only + audio-only DASH streams that need
client-side muxing, which this implementation doesn't do. So even the
"auto-quality" ceiling is lower than the declared priority list suggests, and
there's no visibility into what quality actually got selected.

## Fix options

| Option | Effort | Status | Outcome |
|---|---|---|---|
| **A. Custom quality-selector UI** — read available qualities from `PodPlayerController` / re-derive from the manifest, let the user pick, re-init playback from the chosen stream URL | Medium | **Implemented** | Works within `pod_player`, but still capped by muxed-stream availability (rarely >720p) |
| **B. Adaptive/DASH streams** — use `manifest.videoOnly` + `manifest.audioOnly` and mux client-side, or replace `pod_player` with a player that supports separate video/audio tracks | High | Not started | Unlocks true 1080p/4K, but is a real architecture change away from `pod_player` |
| **C. Read-only quality indicator** — just surface which quality got auto-selected (label only, no picker) | Low | Superseded by A | No new user control, but removes the "silent mystery" of what's currently playing |

## Option A implementation

`pod_player` has no public API to swap quality on a live controller —
`changeVideoQuality()` exists internally
(`pod_video_quality_controller.dart:115-141`) but sits behind a private `_ctr`
field the app can't reach. The implementation works around this entirely
through `PodPlayerController`'s public surface:

1. **Pre-resolve the manifest ourselves.** `_resolveYoutubePlayFrom()`
   (`video_player_page.dart`) calls the static
   `PodPlayerController.getYoutubeUrls(url)` — the same call `pod_player`
   would make internally — up front, instead of handing the URL to
   `PlayVideoFrom.youtube()` and letting the package resolve it opaquely. This
   gives the page the full list of available muxed qualities
   (`_availableQualities`) and lets it pick the initial stream itself via the
   same `[1080, 720, 480, 360]` priority order (`_pickQuality()`). Falls back
   to `PlayVideoFrom.youtube(url)` unchanged if the manifest fetch throws or
   returns empty, so a scrape hiccup degrades to "no switcher" rather than a
   broken player.
2. **UI**: a small pill badge (current quality, e.g. "720p") is overlaid on
   the video via the same `OverlayEntry` + fullscreen-repositioning mechanism
   already used for `_MovingWatermark` (`_showQualityBadgeOverlay()`) — proven
   in this file to survive `pod_player`'s fullscreen route push/pop. Tapping
   it opens a `showModalBottomSheet` list of available qualities
   (`_openQualitySheet()`), checkmarking the active one.
3. **Switching** (`_switchQuality()`): captures `currentVideoPosition` and
   `isVideoPlaying`, calls the public `controller.changeVideo(playVideoFrom:
   PlayVideoFrom.network(<pre-resolved url for that quality>), playerConfig:
   PodPlayerConfig(autoPlay: wasPlaying))`, then `videoSeekTo()` to restore
   position. `changeVideo` is the only public re-init hook `pod_player`
   exposes, so this re-creates the underlying `video_player` controller on
   every quality switch — there's a brief loading flicker, unavoidable
   without forking the package.

Known limits carried over from the root cause: quality options are still
whatever `manifest.muxed` publishes (commonly capped at 720p), and there's no
web support consideration (this app path is mobile-only). Only Option B lifts
the resolution ceiling itself.
