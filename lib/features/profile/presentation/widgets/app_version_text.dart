import 'dart:async';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/services/fcm_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "App Version 1.2.3 +45" text — pulls the running build's version and
/// build number from [PackageInfo] at runtime. Renders a placeholder
/// while the async lookup is still in flight.
///
/// Doubles as a hidden Crashlytics test surface: long-press opens a
/// diagnostics sheet that can throw a Dart exception or trigger a native
/// crash, so QA can confirm reports are flowing into the Firebase
/// dashboard end-to-end. Long-press only, so end users never stumble in.
class AppVersionText extends StatefulWidget {
  const AppVersionText({super.key});

  @override
  State<AppVersionText> createState() => _AppVersionTextState();
}

class _AppVersionTextState extends State<AppVersionText> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _label = "App Version ${info.version}+${info.buildNumber}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _CrashlyticsDiagnostics.show(context),
      child: Text(
        _label ?? "App Version",
        style: AppTypography.bodyTextSmallMedium.copyWith(
          color: AppColors.mutedTextPrimary,
          fontSize: Screen.getFontSize(12),
        ),
      ),
    );
  }
}

/// Hidden bottom-sheet shown after long-pressing the version text.
/// Two paths to test the Crashlytics pipeline:
/// - "Throw Dart error" — uncaught Future error → routed through
///   `PlatformDispatcher.onError` to Crashlytics as a fatal.
/// - "Force native crash" — `FirebaseCrashlytics.instance.crash()`
///   triggers an immediate native SIGSEGV; the report uploads on the
///   next app launch.
class _CrashlyticsDiagnostics extends StatelessWidget {
  const _CrashlyticsDiagnostics();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CrashlyticsDiagnostics(),
    );
  }

  void _throwDartError() {
    // Future.microtask so the throw escapes the current call stack and
    // lands in PlatformDispatcher.onError instead of being caught by the
    // gesture handler. Marked as a synthetic test crash via custom keys.
    FirebaseCrashlytics.instance.setCustomKey('test_trigger', 'dart_throw');
    Future.microtask(() {
      throw Exception('Crashlytics test — uncaught Dart exception');
    });
  }

  void _forceNativeCrash() {
    FirebaseCrashlytics.instance.setCustomKey('test_trigger', 'native_crash');
    // crash() schedules a native SIGSEGV. The app dies; the report
    // uploads on next launch.
    FirebaseCrashlytics.instance.crash();
  }

  /// Copy the cached FCM token to the system clipboard so it can be
  /// pasted into the Firebase Console "Send test message" form when
  /// triaging push-delivery issues without needing a console attached.
  Future<void> _copyFcmToken(BuildContext context) async {
    final token = sl<FcmService>().cachedToken;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (token == null || token.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No FCM token cached yet')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    messenger?.showSnackBar(
      SnackBar(content: Text('FCM token copied (${token.length} chars)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Crashlytics diagnostics',
              style: AppTypography.h6SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Reports only upload from release/profile builds. Open the '
              'app once after the crash for the report to land in Firebase.',
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // FCM debug: copy the cached push token so it can be pasted
            // into the Firebase Console "Send test message" form to
            // isolate client-side delivery issues from server-side
            // sending issues.
            OutlinedButton(
              onPressed: () {
                final sheetContext = context;
                Navigator.of(sheetContext).pop();
                _copyFcmToken(sheetContext);
              },
              child: const Text('Copy FCM token'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _throwDartError();
              },
              child: const Text('Throw Dart error'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _forceNativeCrash();
              },
              child: const Text('Force native crash (will kill app)'),
            ),
          ],
        ),
      ),
    );
  }
}
