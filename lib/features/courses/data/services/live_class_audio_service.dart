import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

const String _kTag = '[ClassAudio]';

/// Reaching the LiveKit SFU failed — the media server is down/unreachable
/// (e.g. nginx answering `502 Bad Gateway` for the `/livekit` upstream),
/// or the network dropped mid-handshake. Distinct from a local microphone
/// failure so the UI can say which side broke instead of blaming the
/// student's device.
class LiveAudioConnectException implements Exception {
  final String url;
  final Object cause;

  const LiveAudioConnectException(this.url, this.cause);

  @override
  String toString() => 'LiveAudioConnectException($url): $cause';
}

/// Audio-only LiveKit wrapper for the raise-hand → speak flow. Students
/// only ever *publish microphone* — never video, never subscribe to
/// other participants (they already hear the educator through the HLS
/// stream). One instance per speaking turn: [connectAndPublish] then
/// [disconnect]; create a fresh one for the next turn.
class LiveClassAudioService {
  Room? _room;

  bool get isConnected => _room != null;

  /// Connects to the LiveKit room with the grant token and enables the
  /// mic. Resolves only once the local audio track is actually
  /// published/live — the caller invokes `MicActivated` on the hub
  /// immediately after this returns. Throws on failure so the caller
  /// can revert the UI.
  Future<void> connectAndPublish({
    required String url,
    required String token,
  }) async {
    await disconnect();
    // Audio-only: no adaptive stream / dynacast (video features), and we
    // don't auto-subscribe — nothing to hear here but our own mic.
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
      ),
    );
    _room = room;
    try {
      // Set the session up for "listening + talking at the same time"
      // BEFORE the mic opens — see [_configureForSpeaking].
      await _configureForSpeaking();
      try {
        await room.connect(
          url,
          token,
          connectOptions: const ConnectOptions(autoSubscribe: false),
        );
      } catch (e) {
        // Signalling never came up — always a server/network fault, never
        // the mic. Tag it with the URL so the failing host is in the log.
        throw LiveAudioConnectException(url, e);
      }
      // Returns the publication once the track is live. The grant token
      // permits microphone only, so this is the whole "go live" step.
      final pub = await room.localParticipant?.setMicrophoneEnabled(true);
      if (pub == null) {
        throw StateError('Microphone publication failed');
      }
      // Communication mode defaults to the earpiece on many devices —
      // force the loudspeaker so the educator's stream stays audible
      // while the student talks.
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('$_kTag setSpeakerphoneOn failed: $e');
      }
      debugPrint('$_kTag mic live sid=${pub.sid}');
    } catch (e) {
      debugPrint('$_kTag connectAndPublish FAILED url=$url: $e');
      await disconnect();
      rethrow;
    }
  }

  /// Prepares the OS audio session for **simultaneous** HLS playback and
  /// mic capture. Without this the student's video freezes the instant
  /// they start speaking:
  ///
  /// * **Android** — WebRTC requests `AUDIOFOCUS_GAIN` by default, which
  ///   ExoPlayer (running the class stream) receives as a permanent
  ///   `AUDIOFOCUS_LOSS` and responds to by pausing. `gainTransientMayDuck`
  ///   asks the player to lower its volume instead of stopping.
  ///   `inCommunication` mode is kept so the hardware echo canceller stays
  ///   on — the mic is open next to a speaker playing the educator.
  /// * **iOS** — the WebRTC session switches to `playAndRecord`, which
  ///   interrupts any other player unless `mixWithOthers` is set.
  Future<void> _configureForSpeaking() async {
    try {
      if (Platform.isAndroid) {
        await rtc.Helper.setAndroidAudioConfiguration(
          rtc.AndroidAudioConfiguration(
            manageAudioFocus: true,
            androidAudioMode: rtc.AndroidAudioMode.inCommunication,
            androidAudioFocusMode:
                rtc.AndroidAudioFocusMode.gainTransientMayDuck,
            androidAudioStreamType: rtc.AndroidAudioStreamType.voiceCall,
            androidAudioAttributesUsageType:
                rtc.AndroidAudioAttributesUsageType.voiceCommunication,
            androidAudioAttributesContentType:
                rtc.AndroidAudioAttributesContentType.speech,
            // Some devices refuse to route while in communication mode
            // unless routing is forced — without it the class audio can
            // drop to the earpiece as soon as the mic opens.
            forceHandleAudioRouting: true,
          ),
        );
      } else if (Platform.isIOS) {
        await rtc.Helper.setAppleAudioConfiguration(
          rtc.AppleAudioConfiguration(
            appleAudioCategory: rtc.AppleAudioCategory.playAndRecord,
            appleAudioCategoryOptions: {
              rtc.AppleAudioCategoryOption.mixWithOthers,
              rtc.AppleAudioCategoryOption.defaultToSpeaker,
              rtc.AppleAudioCategoryOption.allowBluetooth,
            },
            appleAudioMode: rtc.AppleAudioMode.videoChat,
          ),
        );
      }
    } catch (e) {
      // Never block going live on a session-tuning failure — worst case
      // is the old behaviour, which we'd rather have than no mic at all.
      debugPrint('$_kTag audio session config failed: $e');
    }
  }

  /// Hands the session back to plain media playback once the speaking
  /// turn ends, so the class stream isn't left in communication mode
  /// (quieter output, earpiece routing on some devices).
  Future<void> _restoreMediaSession() async {
    try {
      if (Platform.isAndroid) {
        await rtc.Helper.setAndroidAudioConfiguration(
          rtc.AndroidAudioConfiguration.media,
        );
      } else if (Platform.isIOS) {
        await rtc.Helper.setAppleAudioConfiguration(
          rtc.AppleAudioConfiguration(
            appleAudioCategory: rtc.AppleAudioCategory.playback,
            appleAudioCategoryOptions: {
              rtc.AppleAudioCategoryOption.mixWithOthers,
            },
            appleAudioMode: rtc.AppleAudioMode.moviePlayback,
          ),
        );
      }
    } catch (e) {
      debugPrint('$_kTag audio session restore failed: $e');
    }
  }

  /// Fully tears down the LiveKit room — stops publishing and releases
  /// the mic. Safe to call repeatedly / when not connected.
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.localParticipant?.setMicrophoneEnabled(false);
        await room.disconnect();
        await room.dispose();
      } catch (e) {
        debugPrint('$_kTag disconnect error: $e');
      }
      await _restoreMediaSession();
    }
  }
}
