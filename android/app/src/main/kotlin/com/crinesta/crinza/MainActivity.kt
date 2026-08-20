package com.crinesta.crinza

import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and exposes two security-side channels:
 *
 *  - `crinza/screen_capture` — Flutter toggles `setAllowed(bool)` and we
 *    add or clear [WindowManager.LayoutParams.FLAG_SECURE] on the
 *    Activity window. With FLAG_SECURE set, the OS suppresses
 *    screenshots and the screen-recorder/cast pipeline shows a black
 *    frame instead of the app's pixels.
 *
 *  - `crinza/device_security` — Flutter calls `isDeveloperModeEnabled`
 *    and we report the system setting that drives the "Developer
 *    options" menu in Settings.
 *
 * Both are intentionally tiny — every line of native code is something
 * we'd have to re-audit later, so we keep the surface area minimal.
 *
 * Extends [AudioServiceActivity] (itself a `FlutterActivity`) rather than
 * `FlutterActivity` directly: audio_service hands the running engine to
 * its background service through this subclass, and without it every
 * call into the plugin fails with "The Activity class declared in your
 * AndroidManifest.xml is wrong…" — which silently disables the live
 * class's audio-only fallback and its background playback.
 */
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val SCREEN_CAPTURE_CHANNEL = "crinza/screen_capture"
        const val DEVICE_SECURITY_CHANNEL = "crinza/device_security"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CAPTURE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAllowed" -> {
                    val allowed = call.argument<Boolean>("allowed") ?: false
                    runOnUiThread {
                        if (allowed) {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_SECURITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeveloperModeEnabled" -> {
                    val enabled = try {
                        Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                            0,
                        ) != 0
                    } catch (e: Throwable) {
                        // If the lookup fails (locked-down OEM ROM, permission
                        // surprise) we treat the device as "not in dev mode"
                        // so we don't false-positive lock users out. The
                        // server-side audit trail catches the real bad actors.
                        false
                    }
                    result.success(enabled)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Engage FLAG_SECURE the moment the Activity is created so the
        // app's UI is never visible to the screenshot/recording
        // pipeline before Flutter has a chance to read the profile and
        // explicitly relax it. Same secure-by-default posture as the
        // Dart model.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
