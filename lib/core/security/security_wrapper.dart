import 'package:nexora/core/security/device_security_guard.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// App-root sentry that gates [child] behind a device-integrity probe.
///
/// Behaviour:
///   - On mount, probes once via [DeviceSecurityGuard].
///   - Subscribes to `AppLifecycleState` and re-probes whenever the
///     app comes back to `resumed` (covers the case where a user
///     toggles developer options or jailbreaks the device while we're
///     backgrounded).
///   - While the verdict is OK, renders [child] untouched.
///   - When the verdict is compromised, renders [_SecurityBlockScreen]
///     in place of [child] — a non-dismissible full-screen page with
///     an explanation and a "Re-check" button.
///
/// The block screen is rendered as a sibling of the app's Router so it
/// can't be navigated past, even with deep links — the wrapper sits
/// above the `MaterialApp.router` in the widget tree.
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper>
    with WidgetsBindingObserver {
  DeviceSecurityVerdict _verdict = DeviceSecurityVerdict.ok;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run the first probe after the initial frame so the splash isn't
    // covered by our block screen before the user has even seen the
    // app render.
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _probe();
    }
  }

  Future<void> _probe() async {
    if (_probing) return;
    _probing = true;
    try {
      final next = await DeviceSecurityGuard.instance.probe();
      if (!mounted) return;
      setState(() => _verdict = next);
    } finally {
      _probing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_verdict.isCompromised) return widget.child;
    // Wrap in its own MaterialApp so the block screen renders cleanly
    // (text direction, theming, MediaQuery) without sharing the
    // routing app's navigator — guarantees the user can't pop or deep-
    // link past us.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _SecurityBlockScreen(
        verdict: _verdict,
        onRecheck: _probe,
      ),
    );
  }
}

/// Full-screen non-dismissible block. PopScope guards against the
/// system back button; there is no AppBar / drawer / dismiss action,
/// so the only exit is the "Re-check" button after fixing the
/// underlying condition.
class _SecurityBlockScreen extends StatelessWidget {
  final DeviceSecurityVerdict verdict;
  final VoidCallback onRecheck;

  const _SecurityBlockScreen({
    required this.verdict,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Screen.getHorizontalSize(24),
              vertical: Screen.getVerticalSize(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: Screen.getSize(72),
                  color: AppColors.primary,
                ),
                SizedBox(height: Screen.getVerticalSize(20)),
                Text(
                  'Device security check failed',
                  textAlign: TextAlign.center,
                  style: AppTypography.h4SemiBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: Screen.getFontSize(22),
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(16)),
                Text(
                  verdict.blockReason,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                    fontSize: Screen.getFontSize(14),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(32)),
                SizedBox(
                  height: Screen.getVerticalSize(52),
                  child: ElevatedButton(
                    onPressed: onRecheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Screen.getSize(14),
                        ),
                      ),
                    ),
                    child: Text(
                      'Re-check',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.alwaysWhite,
                        fontSize: Screen.getFontSize(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
