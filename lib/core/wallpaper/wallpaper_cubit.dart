import 'dart:io';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/constants/storage_keys.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the student's custom app background — a photo they pick from
/// their gallery or camera, painted behind Home, Profile and the chat
/// rooms.
///
/// Entirely on-device: the picked image is copied into the app's own
/// documents directory (the picker's copy lives in a cache the OS may
/// purge), and only its file name is persisted. Nothing is uploaded.
///
/// The state is the image to paint: the bundled theme background, the
/// student's own photo, or `null` for no background at all. Like
/// `ThemeCubit` it is a plain state rather than a Freezed union — there
/// is no loading or error to show; a failed read just means the default.
///
/// [load] is awaited during bootstrap so the first frame of Home already
/// has the background instead of popping it in a moment later.
enum WallpaperMode { none, theme, custom }

class WallpaperCubit extends SafeCubit<ImageProvider?> {
  final FlutterSecureStorage _storage;

  /// The bundled theme background everyone starts with. Always this file
  /// name — swap the artwork by replacing the file.
  static const defaultAsset = 'assets/images/backgrounds/login_background.png';

  /// The student's own photo, kept while another mode is active so they
  /// can flip back to it without picking again.
  File? _custom;
  File? get custom => _custom;

  WallpaperMode _mode = WallpaperMode.theme;
  WallpaperMode get mode => _mode;

  WallpaperCubit(this._storage) : super(const AssetImage(defaultAsset));

  void _apply(WallpaperMode mode) {
    // Custom with no photo has nothing to show — fall back to the theme.
    if (mode == WallpaperMode.custom && _custom == null) {
      mode = WallpaperMode.theme;
    }
    _mode = mode;
    emit(switch (mode) {
      WallpaperMode.none => null,
      WallpaperMode.theme => const AssetImage(defaultAsset),
      WallpaperMode.custom => FileImage(_custom!),
    });
  }

  Future<void> _persistMode() async {
    try {
      await _storage.write(key: StorageKeys.wallpaperMode, value: _mode.name);
    } catch (e) {
      debugPrint('WallpaperCubit: mode persist failed: $e');
    }
  }

  /// Switch mode (none / theme / the saved custom photo) and remember it.
  Future<void> select(WallpaperMode mode) async {
    _apply(mode);
    await _persistMode();
  }

  static const _dirName = 'wallpaper';

  /// Long edge cap for the stored copy. Enough to cover a phone screen
  /// at full resolution under `BoxFit.cover`, while keeping the decoded
  /// bitmap to a few MB rather than a 12-megapixel camera original.
  static const double _maxEdge = 2048;

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$_dirName');
  }

  /// Restore the saved background. Never throws — a missing file (the
  /// user cleared app data, or a restore skipped it) quietly drops the
  /// stale key and leaves the default look.
  Future<void> load() async {
    try {
      final name = await _storage.read(key: StorageKeys.wallpaperFile);
      if (name != null) {
        final file = File('${(await _dir()).path}/$name');
        if (await file.exists()) {
          _custom = file;
        } else {
          await _storage.delete(key: StorageKeys.wallpaperFile);
        }
      }
      final raw = await _storage.read(key: StorageKeys.wallpaperMode);
      _apply(
        WallpaperMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => WallpaperMode.theme,
        ),
      );
    } catch (e) {
      debugPrint('WallpaperCubit.load failed, using default: $e');
    }
  }

  /// Let the student pick a photo and make it the background.
  ///
  /// Returns `false` when they back out of the picker. Throws on a real
  /// failure (permission denied, disk full) so the caller can tell them;
  /// the previous background is left untouched in that case.
  Future<bool> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final dir = await _dir();
    await dir.create(recursive: true);
    // A fresh name every time rather than overwriting one fixed file:
    // Flutter's image cache is keyed by path, so reusing the name would
    // keep painting the old photo until the app restarts.
    final dot = picked.path.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : picked.path.substring(dot + 1);
    final name = 'wallpaper_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final saved = await File(picked.path).copy('${dir.path}/$name');

    final previous = _custom;
    await _storage.write(key: StorageKeys.wallpaperFile, value: name);
    _custom = saved;
    _apply(WallpaperMode.custom);
    await _persistMode();
    if (previous != null) await _deleteQuietly(previous);
    return true;
  }

  /// Back to the theme background, deleting the stored photo. Safe to
  /// call with none chosen — logout calls it unconditionally.
  Future<void> remove() async {
    final previous = _custom;
    _custom = null;
    _apply(WallpaperMode.theme);
    try {
      await _storage.delete(key: StorageKeys.wallpaperFile);
      await _storage.delete(key: StorageKeys.wallpaperMode);
    } catch (e) {
      debugPrint('WallpaperCubit.remove: key delete failed: $e');
    }
    if (previous != null) await _deleteQuietly(previous);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      // An orphaned file in our own documents dir costs some disk and
      // nothing else; not worth surfacing.
      debugPrint('WallpaperCubit: could not delete ${file.path}: $e');
    }
  }
}
