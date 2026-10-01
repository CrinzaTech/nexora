import 'dart:io';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/wallpaper/wallpaper_cubit.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/profile/presentation/widgets/profile_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Profile row for the app background. Shows the current choice in place
/// of the chevron — a thumbnail for a custom photo, a label otherwise;
/// tapping opens [_WallpaperSheet].
class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key});

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<WallpaperCubit>();
    final action = await showModalBottomSheet<_WallpaperAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _WallpaperSheet(mode: cubit.mode, custom: cubit.custom),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _WallpaperAction.none:
        await cubit.select(WallpaperMode.none);
      case _WallpaperAction.theme:
        await cubit.select(WallpaperMode.theme);
      case _WallpaperAction.useCustom:
        await cubit.select(WallpaperMode.custom);
      case _WallpaperAction.pickCustom:
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (_) => const _SourceSheet(),
        );
        if (source == null || !context.mounted) return;
        await _pick(context, cubit, source);
    }
  }

  Future<void> _pick(
    BuildContext context,
    WallpaperCubit cubit,
    ImageSource source,
  ) async {
    try {
      final changed = await cubit.pick(source);
      if (changed && context.mounted) {
        CustomSnackbar.success(
          context,
          title: 'Background updated',
          message: 'Your photo now shows on Home, Profile and Chats.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Wallpaper pick failed: ${e.code}');
      if (!context.mounted) return;
      final denied = e.code.contains('denied');
      CustomSnackbar.error(
        context,
        title: denied ? 'Access needed' : 'Couldn\'t set background',
        message: denied
            ? source == ImageSource.camera
                  ? 'Allow camera access in Settings to take a photo.'
                  : 'Allow photo access in Settings to choose a background.'
            : 'Something went wrong. Please try another photo.',
      );
    } catch (e) {
      debugPrint('Wallpaper save failed: $e');
      if (!context.mounted) return;
      CustomSnackbar.error(
        context,
        title: 'Couldn\'t set background',
        message: 'Something went wrong. Please try another photo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<WallpaperCubit>();
    final custom = cubit.custom;
    return CustomProfileListTileWidget(
      title: 'App Background',
      leadingIconData: Icons.wallpaper_rounded,
      onTap: () => _open(context),
      trailing: cubit.mode == WallpaperMode.custom && custom != null
          ? _Thumbnail(file: custom, size: Screen.getSize(30))
          : Text(
              cubit.mode == WallpaperMode.none ? 'None' : 'Theme',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSizeCapped(13),
              ),
            ),
    );
  }
}

/// [useCustom] re-selects the photo already saved; [pickCustom] asks for a
/// new one (first time, or tapping the already-active custom square).
enum _WallpaperAction { none, theme, useCustom, pickCustom }

class _WallpaperSheet extends StatelessWidget {
  final WallpaperMode mode;
  final File? custom;

  const _WallpaperSheet({required this.mode, required this.custom});

  @override
  Widget build(BuildContext context) {
    final gap = Screen.getHorizontalSize(12);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: Screen.getPadding(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Background',
              style: AppTypography.h6SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(4)),
            Text(
              'Shown on Home, Profile and Chats. Saved on this device only.',
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(18)),
            Row(
              children: [
                Expanded(
                  child: _ChoiceSquare(
                    label: 'None',
                    selected: mode == WallpaperMode.none,
                    onTap: () => Navigator.pop(context, _WallpaperAction.none),
                    child: ColoredBox(
                      color: AppColors.grey100,
                      child: Center(
                        child: Icon(
                          Icons.hide_image_outlined,
                          size: Screen.getSize(30),
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _ChoiceSquare(
                    label: 'Theme',
                    selected: mode == WallpaperMode.theme,
                    onTap: () => Navigator.pop(context, _WallpaperAction.theme),
                    child: Image.asset(
                      WallpaperCubit.defaultAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _ChoiceSquare(
                    label: 'Custom',
                    selected: mode == WallpaperMode.custom,
                    // A saved photo that isn't active just re-selects;
                    // tapping the active one (or having none) picks anew.
                    onTap: () => Navigator.pop(
                      context,
                      custom != null && mode != WallpaperMode.custom
                          ? _WallpaperAction.useCustom
                          : _WallpaperAction.pickCustom,
                    ),
                    child: custom == null
                        ? ColoredBox(
                            color: AppColors.grey100,
                            child: Center(
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: Screen.getSize(30),
                                color: AppColors.mutedTextPrimary,
                              ),
                            ),
                          )
                        : Image.file(
                            custom!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                ColoredBox(color: AppColors.grey100),
                          ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            if (custom != null)
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, _WallpaperAction.pickCustom),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: Screen.getSize(16),
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'Change custom photo',
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            SizedBox(height: Screen.getVerticalSize(8)),
          ],
        ),
      ),
    );
  }
}

/// One square choice: the preview, a label under it, and a highlighted
/// ring + tick when it is the active background.
class _ChoiceSquare extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ChoiceSquare({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusL);
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.grey200,
                  width: selected ? 2.5 : 1,
                ),
              ),
              padding: EdgeInsets.all(selected ? 2 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusL - 2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: Screen.getSize(14),
                            color: AppColors.onFill(AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: Screen.getVerticalSize(6)),
        Text(
          label,
          style: AppTypography.bodyTextMedium.copyWith(
            color: selected
                ? AppColors.textPrimary
                : AppColors.mutedTextPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Where to get the custom photo from.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: Screen.getPadding(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _SheetOption(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Padding(
        padding: Screen.getPadding(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: Screen.getSize(22), color: tint),
            SizedBox(width: Screen.getHorizontalSize(14)),
            Text(
              label,
              style: AppTypography.bodyTextLargeMedium.copyWith(color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final File file;
  final double size;

  const _Thumbnail({required this.file, required this.size});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: AppColors.grey200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        // A 30 px chip doesn't need the full-screen decode.
        cacheWidth: (size * dpr).round(),
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
