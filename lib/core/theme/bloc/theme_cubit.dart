import 'package:flutter/material.dart';
import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:nexora/core/constants/storage_keys.dart';
import 'package:nexora/core/router/app_routes.dart';

/// Owns the app-wide light/dark preference.
///
/// The state *is* the [ThemeMode] — there's no loading/error variant to
/// model, so a plain `Cubit<ThemeMode>` is a better fit here than the
/// Freezed union the feature cubits use. A read failure just falls back
/// to [ThemeMode.system]; there is nothing useful to show the user.
///
/// [load] must be awaited during bootstrap, before `runApp`, so the
/// very first frame paints in the user's chosen theme instead of
/// flashing light and then correcting itself.
class ThemeCubit extends SafeCubit<ThemeMode> {
  final FlutterSecureStorage _storage;

  ThemeCubit(this._storage) : super(ThemeMode.system);

  /// Restore the persisted preference. Never throws — a keystore that
  /// refuses to read leaves the app on [ThemeMode.system].
  Future<void> load() async {
    try {
      final raw = await _storage.read(key: StorageKeys.themeMode);
      emit(_decode(raw));
    } catch (e) {
      debugPrint('ThemeCubit.load failed, falling back to system: $e');
    }
  }

  /// Switch to an explicit mode and persist it.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    repaintEntireTree();
    try {
      await _storage.write(key: StorageKeys.themeMode, value: _encode(mode));
    } catch (e) {
      // The UI has already flipped; the choice just won't survive a
      // restart. Not worth interrupting the user over.
      debugPrint('ThemeCubit.setMode persist failed: $e');
    }
  }

  /// Flip between light and dark.
  ///
  /// [isCurrentlyDark] comes from the caller because [ThemeMode.system]
  /// can't answer "am I dark right now?" on its own — only the platform
  /// brightness in the widget tree can. Toggling out of `system` always
  /// lands on an explicit mode, which is what a user expects from a
  /// switch: flipping it should stick regardless of what the OS does
  /// next.
  Future<void> toggle({required bool isCurrentlyDark}) =>
      setMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);

  static ThemeMode _decode(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

/// Force every widget in the tree to run `build()` again.
///
/// Needed because the app's colours come from `AppColors` statics, not
/// from `Theme.of(context)`. Nothing registers as a dependent of the
/// `Theme` inherited widget, so a theme change does not, on its own,
/// invalidate anything — and Flutter skips rebuilding a subtree whose
/// widget instance is unchanged. With 400-odd `const` widget sites in
/// this app, a plain `MaterialApp` rebuild leaves large parts of the UI
/// painted in the previous palette.
///
/// Marking every element dirty is what hot reload does, and unlike
/// re-keying the subtree it rebuilds **in place**: `State` objects,
/// scroll offsets, the dashboard's current tab, and in-flight form
/// input all survive. The cost is one full rebuild, which is
/// unnoticeable for something a user does by hand.
///
/// Deferred to after the current frame because `markNeedsBuild` asserts
/// if called while a build is already in progress.
void repaintEntireTree() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    mark(root);
  });
}

/// The mode the app should actually paint at, given the user's
/// [preference] and the route currently on screen.
///
/// A handful of screens are pinned to the light palette because they are
/// drawn over fixed light artwork — see [AppRoutes.alwaysLightRoutes].
/// Everything else honours the preference.
///
/// [location] is nullable because the router has no resolved route
/// before the first frame; a null location can only mean "nothing is on
/// screen yet", so the preference wins.
///
/// Pure on purpose — the caller reads the live location and passes it
/// in, which keeps this decision testable without a router.
ThemeMode resolveThemeMode(ThemeMode preference, String? location) {
  // Already light: no route can make it lighter, so skip the lookup.
  if (preference == ThemeMode.light || location == null) return preference;
  return AppRoutes.isAlwaysLight(location) ? ThemeMode.light : preference;
}

/// Resolves "is the app dark right now?" for a given [BuildContext].
///
/// Under [ThemeMode.system] the answer lives in the platform
/// brightness, not in the cubit — so anything rendering a light/dark
/// affordance has to ask the tree, not just the state.
extension ThemeModeResolution on ThemeMode {
  bool isDarkIn(BuildContext context) => switch (this) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };
}
