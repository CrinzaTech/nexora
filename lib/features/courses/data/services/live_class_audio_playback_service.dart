import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// Media-session holder for the live-class background mode.
///
/// This deliberately does **not** play anything. Audio in the background is
/// produced by the same `better_player_plus` controller that plays the
/// video: on backgrounding it's capped to the audio-only HLS rendition, so
/// there is no second player and no handoff at all.
///
/// It used to drive a `just_audio` player, which never worked — that player
/// could not load the audio-only MPEG-TS rendition on any configuration we
/// tried (awaited, unawaited, preload on/off, warm-muted): it sat in
/// `loading` indefinitely, never opened a decoder, and never made a sound,
/// while the very same stream played fine through media3 in the video
/// player.
///
/// What this class is still needed for is the **foreground service**.
/// `audio_service` promotes itself to one when a playing state is published,
/// and that is what stops Android freezing the process once the screen goes
/// off — without it the video player is killed and background audio dies.
/// It also supplies the lock-screen / notification controls.
///
/// `audio_service` requires exactly one [AudioService.init] per app run —
/// [LiveAudioPlaybackService.instance] guards that and hands back the same
/// long-lived handler on every live-class entry.
class LiveAudioHandler extends BaseAudioHandler {
  bool _held = false;

  /// True while the session (and therefore the foreground service) is held.
  bool get isHeld => _held;

  /// Claim the media session so Android keeps the process alive and shows
  /// lock-screen controls. Publish this while still in the foreground —
  /// Android only permits starting a foreground service from there.
  Future<void> holdSession({required String title}) async {
    _held = true;
    mediaItem.add(
      MediaItem(
        id: 'live-class',
        title: title,
        album: 'Live class',
        isLive: true,
        playable: true,
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        controls: [MediaControl.stop],
        systemActions: const {},
      ),
    );
    debugPrint('[LiveAudio] session held (foreground service)');
  }

  /// Drop the session and its notification.
  Future<void> releaseSession() async {
    if (!_held) return;
    _held = false;
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: const [],
      ),
    );
    debugPrint('[LiveAudio] session released');
  }

  /// The notification's stop button — surfaced to the page so it can leave
  /// the class cleanly rather than stranding a silent session.
  @override
  Future<void> stop() async {
    await releaseSession();
    return super.stop();
  }
}

/// Lazily initialises and caches the single [LiveAudioHandler].
class LiveAudioPlaybackService {
  LiveAudioPlaybackService._();

  static LiveAudioHandler? _handler;
  static Future<LiveAudioHandler>? _pending;

  /// Returns the app-wide handler, initialising `audio_service` on first
  /// use. Safe to call repeatedly and concurrently.
  static Future<LiveAudioHandler> instance() {
    if (_handler != null) return Future.value(_handler);
    return _pending ??= AudioService.init(
      builder: () => LiveAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.crinesta.crinza.live_audio',
        androidNotificationChannelName: 'Live class audio',
        // Keep the foreground service alive across a pause so the process
        // (and the SignalR connection) isn't frozen while backgrounded —
        // the class stays "alive" in the admin panel until the app is
        // actually killed. (Ongoing must be false when stop-on-pause is
        // false — audio_service asserts this.)
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    ).then((handler) {
      _handler = handler;
      return handler;
    });
  }
}
