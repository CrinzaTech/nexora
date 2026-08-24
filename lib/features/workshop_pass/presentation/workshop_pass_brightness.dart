import 'package:screen_brightness/screen_brightness.dart';

import 'package:nexora/core/utils/utils.dart';

/// Turns the screen up while a pass is on display, and puts it back
/// afterwards.
///
/// **The single biggest thing the app can do for scan reliability.** A
/// dark pass design — Midnight Premium, Neon Pulse — at 20% brightness
/// under venue lighting is genuinely hard for a door scanner to read,
/// and the attendee is usually holding a phone that dimmed itself while
/// they queued.
///
/// Application-scoped, not system-scoped: the OS restores the user's own
/// brightness when the app goes to the background, so nothing here can
/// leave a phone stuck at full brightness.
///
/// Every call is guarded. A device that refuses the request (no
/// permission, an unsupported platform, a manufacturer skin that owns
/// the setting) is a slightly dimmer pass, never a crash on the way to a
/// ticket.
abstract final class WorkshopPassBrightness {
  static Future<void> boost() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (e) {
      Utils.debugLog('WorkshopPassBrightness: could not raise brightness — $e');
    }
  }

  static Future<void> restore() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      Utils.debugLog(
        'WorkshopPassBrightness: could not restore brightness — $e',
      );
    }
  }
}
