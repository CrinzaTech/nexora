import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

/// Custom splash screen — full-bleed [AppImages.splashBackground]
/// behind the brand logo, with a subtle scale-pulse that reads as a
/// lightweight loading affordance. Falls back to a solid
/// [AppColors.primary] tile if the splash-background asset can't be
/// loaded (e.g. on a fresh clone where the PNG hasn't been dropped
/// in yet) so the splash never renders blank.
///
/// Lifecycle:
///   • `_pulseController` runs a continuous breath (scale 0.94 ↔ 1.0)
///     so the logo never sits perfectly still while the app boots.
///   • `_entryController` does a one-shot fade + initial scale-up the
///     moment the screen mounts.
///   • Once the entry animation completes the screen pauses for a
///     beat, then routes to dashboard / login depending on session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    // One-shot entry: 0 → 1 fade + 0.85 → 1.0 scale over 600 ms.
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entryScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    // Continuous breath: 0.94 ↔ 1.0 with `reverse` chaining via the
    // controller's repeat(reverse: true) — gives a calm in/out cycle.
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _pulseScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
    // Start the breath as soon as the entry animation finishes so the
    // two never visibly fight each other on the scale axis.
    _entryController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) _pulseController.repeat(reverse: true);
        // Hold on the splash for a moment after the entry resolves —
        // gives the user time to register the brand mark before we
        // navigate away.
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          final session = sl<SessionService>();
          final isLoggedIn = session.isLoggedIn;
          if (isLoggedIn && !session.isProfileComplete) {
            // New-user token exists but the mandatory setup-profile
            // form was never submitted (e.g. app was killed/cache was
            // cleared between OTP verify and form submission). Send
            // them back to the form instead of the dashboard.
            context.go(AppRoutes.setupProfile);
          } else if (isLoggedIn) {
            context.go(AppRoutes.dashboard);
          } else {
            // Show the Org Code gate only when ORG_ID is CRINZA and platform is iOS.
            final orgId = dotenv.env['ORG_ID'] ?? '';
            final isIosAndCrinza = !kIsWeb && Platform.isIOS && orgId.toUpperCase() == 'CRINZA';
            final destination = isIosAndCrinza
                ? AppRoutes.orgCode
                : AppRoutes.login;
            context.go(destination);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Brand colour as the underlying surface — guarantees a
      // non-blank backdrop even if `splashBackground` isn't on disk
      // (errorBuilder below also defers to this fill).
      backgroundColor: AppColors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppImages.splashBackground,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            // Missing-asset fallback: the splash never renders a
            // broken-image glyph; it just lands on the primary tile.
            errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.primary),
          ),
          Center(
            child: FadeTransition(
              opacity: _entryFade,
              // Two scale animations multiplied together: the entry
              // tween brings the logo up from 0.85 → 1.0, then the
              // breath pulse takes over and modulates around 0.94–1.0
              // forever after.
              child: AnimatedBuilder(
                animation: Listenable.merge([_entryScale, _pulseScale]),
                builder: (context, child) {
                  final base = _entryScale.value;
                  // Only mix in the breath once the entry has finished
                  // — otherwise both controllers fight for the first
                  // 600 ms.
                  final breath = _entryController.isCompleted
                      ? _pulseScale.value
                      : 1.0;
                  return Transform.scale(scale: base * breath, child: child);
                },
                child: Image.asset(
                  AppImages.logo,
                  width: 200,
                  height: 200,
                  // Required, not cosmetic: `Image` leaves `fit` null and
                  // paintImage then falls back to BoxFit.scaleDown, which
                  // only ever shrinks. logo.png is a 125×126 asset with no
                  // 2x/3x variants, so without an explicit `contain` the
                  // width/height above are ignored and the mark paints at
                  // its intrinsic 125px however large a box we give it.
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
