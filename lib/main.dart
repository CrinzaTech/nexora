import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/di/dependency_injection.dart';
import 'core/router/app_router.dart';
import 'core/security/security_wrapper.dart';
import 'core/services/content_completion_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/notification_router.dart';
import 'core/session/session_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_cubit.dart';
import 'core/theme/branding_config.dart';
import 'features/profile/presentation/bloc/profile_cubit.dart';
import 'firebase_options.dart';

void main() {
  // runZonedGuarded catches any error not handled by an explicit try/catch
  // below — including the otherwise-fatal "uncaught async error before
  // runApp" case that closes the app the moment it opens. Once the zone
  // has caught it, runApp still gets called so the user lands on the
  // splash/login screen instead of a black slam-shut.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Each init step is independently guarded — a single plugin failing
      // (e.g. dotenv missing the asset, Firebase mismatch, secure-storage
      // refusing to talk to the platform keystore on a hardened OEM ROM)
      // logs and keeps moving instead of taking the whole app down.
      // DM Sans ships in `assets/fonts/` (DMSans-Regular/Medium/SemiBold/
      // Bold.ttf). google_fonts resolves a family from the asset manifest
      // before it considers the network, so those four files are all it
      // ever needs. Turning runtime fetching off makes that guarantee
      // explicit: no request to fonts.gstatic.com on first launch, no
      // unstyled-text flash, and no "Failed to load font" / "Connection
      // closed while receiving data" errors for users on weak or
      // Google-blocking networks. A missing weight now fails loudly in
      // development instead of quietly downloading in production.
      GoogleFonts.config.allowRuntimeFetching = false;

      await _safeInit('dotenv', () => dotenv.load(fileName: '.env'));
      await _safeInit(
        'firebase',
        () => Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
      );

      // Crashlytics — gate collection on release/profile so debug stack
      // traces don't pollute the dashboard. Has to come AFTER Firebase init,
      // which is why we call it again inside the awaits below; setting up
      // the error redirects is fine to do up-front because they only call
      // into Crashlytics if Firebase is up.
      final crashlytics = FirebaseCrashlytics.instance;

      // Render-pipeline / framework errors, and async errors that escape
      // the framework's zone (an unhandled Future in a button callback,
      // say). Both are recorded as NON-fatal, because both handlers let
      // the app carry on afterwards — `presentError` draws the error
      // widget and `onError` returns true to swallow the throw. Filing
      // them as fatal made the Crashlytics dashboard report "crashes" for
      // sessions the user never saw end: a font download timing out and a
      // cubit emitting into a screen the user had already left both
      // arrived as top-of-list fatals.
      //
      // Nothing is lost by demoting them. Genuine process death — native
      // crashes, ANRs, OOM kills — is captured by the Crashlytics SDK
      // itself and never passes through these two callbacks.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: false);
        return true;
      };

      // Disable Crashlytics in debug builds so local stack traces don't
      // pollute the dashboard. Wrapped because if Firebase init failed
      // above, Crashlytics methods will throw "no app".
      await _safeInit(
        'crashlytics-toggle',
        () => crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode),
      );

      // Background handler MUST be registered before any other FCM call.
      // Wrap because Firebase init above can fail.
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e, st) {
        debugPrint('FCM background handler registration failed: $e');
        debugPrintStack(stackTrace: st);
      }

      // `secureStorage`, never a fresh FlutterSecureStorage() — a second
      // instance with different Android options migrates this one's keys
      // out from under it and the session reads back null on the next
      // launch. See core/storage/secure_storage.dart.
      final sessionService = SessionService(secureStorage);
      await _safeInit('session', () => sessionService.init());
      sl.registerLazySingleton<SessionService>(() => sessionService);

      final localNotifications = LocalNotificationService();
      await _safeInit(
        'local_notifications',
        () => localNotifications.init(
          // Foreground FCM messages get bridged into local notifications
          // by FcmService — when the user taps one of those tray banners
          // the payload is the same `key=value&key=value` string we
          // encoded on the way in. Decode it and run it through the
          // same deep-linker the background-tap path uses so both
          // surfaces land on the same screen.
          onTap: (payload) {
            debugPrint('Local notification tapped — payload=$payload');
            NotificationRouter.route(FcmService.decodePayload(payload));
          },
          // Same tap, but it launched the process from terminated. The
          // splash still owns the navigator, so park the link instead of
          // routing it — SplashScreen replays it once it has landed on
          // the dashboard.
          onLaunchTap: (payload) {
            debugPrint('Local notification launched app — payload=$payload');
            NotificationRouter.park(FcmService.decodePayload(payload));
          },
        ),
      );
      sl.registerLazySingleton<LocalNotificationService>(
        () => localNotifications,
      );

      final fcmService = FcmService(sessionService, localNotifications);
      // Deep-link tap routing — fires for warm-resume (`onMessageOpenedApp`)
      // and cold-start (`getInitialMessage`, deferred to the first frame
      // by FcmService so the router has mounted).
      fcmService.onNotificationTap = NotificationRouter.route;
      // Cold-start taps get parked, not routed — see NotificationRouter's
      // "Cold-start parking" note. SplashScreen replays them.
      fcmService.onColdStartNotificationTap = NotificationRouter.park;
      sl.registerLazySingleton<FcmService>(() => fcmService);
      await _safeInit('fcm', () => fcmService.init());

      // DI is non-optional — but we still wrap so a registration error logs
      // before runApp kicks in and the user sees the routing-error screen
      // instead of an instant exit.
      await _safeInit('di', () async => setupLocator());

      // Restore the saved light/dark choice BEFORE runApp so the first
      // frame already paints in the user's theme — loading it after
      // would flash light and then correct itself. Failure leaves the
      // cubit on ThemeMode.system, which is a fine default.
      await _safeInit('theme', () => sl<ThemeCubit>().load());

      // Push the freshest FCM token to the backend on every cold start.
      // Fire-and-forget: ProfileCubit.syncFcmToken silently no-ops if not
      // logged in or no token cached, so this is safe even on the very
      // first launch before signup.
      unawaited(
        _safeInit('fcm-token-sync', () => sl<ProfileCubit>().syncFcmToken()),
      );

      // Redeliver any content completions stranded by a previous run
      // (student cleared 75% / opened a doc while offline) and start
      // watching connectivity so a later reconnect drains the queue.
      // Fire-and-forget — it must never delay the first frame.
      unawaited(
        _safeInit(
          'completion-queue',
          () => sl<ContentCompletionService>().init(),
        ),
      );

      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } catch (e) {
        debugPrint('setPreferredOrientations failed: $e');
      }

      // Splash removal at the end so the user only sees the Flutter UI once
      // bootstrapping is past the worst of the failure window.
      FlutterNativeSplash.remove();

      runApp(const CrinzaApp());
    },
    (error, stack) {
      // better_player_plus bug, not ours: its position-polling timer calls
      // DateTime.fromMillisecondsSinceEpoch() on `windowStartTimeMs + pos`.
      // On a live HLS playlist with no #EXT-X-PROGRAM-DATE-TIME (ours has
      // none) windowStartTimeMs is unset, so the sum lands far outside the
      // valid epoch range and throws — every 300ms, for the whole class.
      // It doesn't affect playback, but left alone it buries every real
      // crash in the dashboard. Drop it here rather than fork the package.
      if (error is RangeError && error.name == 'millisecondsSinceEpoch') {
        return;
      }
      // Last-resort catcher for anything that escaped every guard above.
      // Forwarded to Crashlytics as fatal so it lands in the dashboard
      // alongside framework / async errors. Wrapped because Firebase may
      // not be initialised if the bootstrap failed before the firebase
      // init step.
      debugPrint('Uncaught zone error: $error');
      debugPrintStack(stackTrace: stack);
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        // Crashlytics not up — already logged above.
      }
    },
  );
}

/// Re-broadcasts another [Listenable]'s notifications from a point in the
/// event loop where `markNeedsBuild` is always legal.
///
/// Needed because [_CrinzaAppState] listens to the GoRouter delegate from
/// *above* `MaterialApp.router`. The delegate notifies while the Router
/// below is mounting (`setInitialRoutePath` runs inside
/// `didChangeDependencies`), and dirtying an ancestor during that build
/// throws:
///
///     setState() or markNeedsBuild() called during build.
///     This ListenableBuilder widget cannot be marked as needing to build…
///
/// `ChangeNotifier.notifyListeners` catches the assertion, but
/// `FlutterError.onError` still reported it to Crashlytics as fatal on
/// every single cold start.
///
/// The deferral has to be unconditional. Checking
/// `SchedulerBinding.schedulerPhase` first does not work: the root widget
/// is attached from a `Timer` (`WidgetsBinding.scheduleAttachRootWidget`),
/// so that very first mount — the one that trips this — happens *outside*
/// any frame and the phase reads `idle` while a build is very much in
/// progress. `BuildOwner.debugBuilding` would answer correctly but is
/// assert-only, so it is always false in release.
///
/// A microtask is the right tool: builds and frames are synchronous, so a
/// microtask can never run in the middle of one, and it still drains
/// before the next vsync — the rebuild is not a frame late.
class _SafePhaseNotifier extends ChangeNotifier {
  _SafePhaseNotifier(this._source) {
    _source.addListener(_onSourceChanged);
  }

  final Listenable _source;
  bool _disposed = false;
  bool _scheduled = false;

  void _onSourceChanged() {
    // Coalesce bursts — a redirect chain notifies several times for what
    // is a single navigation.
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _source.removeListener(_onSourceChanged);
    super.dispose();
  }
}

/// Run [init], log on failure, never throw. Each call site can read the
/// log to know which step actually failed instead of "the app crashed".
Future<void> _safeInit(String name, Future<dynamic> Function() init) async {
  try {
    await init();
    if (kDebugMode) debugPrint('init OK: $name');
  } catch (e, st) {
    debugPrint('init FAIL [$name]: $e');
    debugPrintStack(stackTrace: st);
  }
}

class CrinzaApp extends StatefulWidget {
  const CrinzaApp({super.key});

  @override
  State<CrinzaApp> createState() => _CrinzaAppState();
}

class _CrinzaAppState extends State<CrinzaApp> with WidgetsBindingObserver {
  /// Route changes, re-broadcast outside the build phase — see
  /// [_SafePhaseNotifier] for why the delegate can't be listened to
  /// directly from here.
  late final _SafePhaseNotifier _routeChanges;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeChanges = _SafePhaseNotifier(AppRouter.router.routerDelegate);
  }

  @override
  void dispose() {
    _routeChanges.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Under [ThemeMode.system] the palette follows the OS, so a change in
  /// platform brightness has to repaint the app the same way an explicit
  /// toggle does — see [repaintEntireTree] for why a plain rebuild isn't
  /// enough. No-op in the explicit light/dark modes, where the OS
  /// setting doesn't affect what we paint.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (sl<ThemeCubit>().state == ThemeMode.system) {
      setState(() {}); // re-resolve _brightnessFor below
      repaintEntireTree();
    }
  }

  /// The brightness the app should paint at, taken from the cubit rather
  /// than from `Theme.of(context)`.
  ///
  /// Reading it back off the resolved theme looks tidier but is wrong:
  /// MaterialApp cross-fades themes through `AnimatedTheme`, and
  /// `ThemeData.lerp` only switches `brightness` at the halfway point of
  /// that animation. The tree repaint triggered by a toggle runs on the
  /// very next frame — long before the midpoint — so every widget that
  /// reads the `AppColors` statics would repaint in the OLD palette and
  /// never be invalidated again. Deriving it from the mode makes the new
  /// value available on the first frame.
  ///
  /// `platformDispatcher` rather than `MediaQuery` because this widget
  /// sits above `MaterialApp`, where no MediaQuery ancestor exists.
  Brightness _brightnessFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  /// The route currently on screen, or null before the first one
  /// resolves.
  ///
  /// Read straight off the delegate rather than via `GoRouterState.of`
  /// because this runs *above* `MaterialApp.router`, where no Router is
  /// in scope yet. Guards on `isEmpty` instead of using the delegate's
  /// `state` getter, which throws on an empty match list.
  String? get _currentLocation {
    final config = AppRouter.router.routerDelegate.currentConfiguration;
    return config.isEmpty ? null : config.uri.path;
  }

  @override
  Widget build(BuildContext context) {
    // App-wide ProfileCubit so Home, Profile, and Edit Profile all observe
    // and write to the same instance. The cubit is a DI singleton; using
    // BlocProvider.value keeps it alive across navigation rather than
    // closing it when this widget rebuilds.
    //
    // SecurityWrapper sits ABOVE the MaterialApp.router so that, when the
    // device-integrity probe fails, the wrapper can swap the entire app
    // for a non-dismissible block screen — no deep link / system back
    // can route past it.
    return SecurityWrapper(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileCubit>.value(value: sl<ProfileCubit>()),
          // Sits above MaterialApp so the profile toggle can reach it
          // and a mode change rebuilds the whole app, not one subtree.
          BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            // Rebuilds on every navigation, which is what lets the
            // always-light routes below take effect: the delegate is a
            // ChangeNotifier and sits *below* this builder, so a route
            // change repaints the palette before the new page builds.
            return ListenableBuilder(
              listenable: _routeChanges,
              builder: (context, _) {
                final effectiveMode = resolveThemeMode(
                  themeMode,
                  _currentLocation,
                );
                // Set before MaterialApp is constructed, so the ThemeData
                // getters below and every widget in this frame agree on one
                // palette. AppTheme's getters save/restore the flag around
                // their own build, so evaluating both themes leaves it here.
                AppColors.applyBrightness(_brightnessFor(effectiveMode));

                return MaterialApp.router(
                  title: currentBranding.appName,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: effectiveMode,
                  // No cross-fade. Only theme-driven widgets can animate; the
                  // ones reading AppColors statics switch instantly, so a
                  // 200ms fade just means 200ms of the two halves disagreeing.
                  themeAnimationDuration: Duration.zero,
                  routerConfig: AppRouter.router,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) {
                    // Cap the system text scale so OS "Large Text" /
                    // accessibility font-size settings can't blow up the app
                    // layout. All font sizes already go through
                    // Screen.getFontSize() which scales relative to the
                    // device screen — a further 2× OS multiplier would break
                    // every carefully sized container.
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: MediaQuery.of(context).textScaler.clamp(
                          minScaleFactor: 1.0,
                          maxScaleFactor: 1.0,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
