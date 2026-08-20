import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/screen.dart';
import 'scrolling_title.dart';

/// Custom AppBar widget for consistent styling across the app
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  /// Bar background. Null — the default — follows the active theme via
  /// `AppColors.white`. It can't be defaulted in the constructor because
  /// that token is a getter, and a `const` constructor needs a constant.
  final Color? backgroundColor;

  /// Title and back-chevron colour. Null follows the active theme.
  final Color? titleColor;

  final bool showBackButton;
  final double? elevation;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final TextStyle? titleStyle;
  final double? titleSpacing;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.onBackPressed,
    this.actions,
    this.backgroundColor,
    this.titleColor,
    this.showBackButton = true,
    this.elevation = 0,
    this.bottom,
    this.centerTitle = true,
    this.titleStyle,
    this.titleSpacing,
  });

  @override
  Widget build(BuildContext context) {
    // Resolved here rather than in the constructor — see the field docs.
    final barColor = backgroundColor ?? AppColors.white;
    final onBarColor = titleColor ?? AppColors.textPrimary;

    return AppBar(
      backgroundColor: barColor,
      surfaceTintColor: barColor,
      elevation: elevation,
      bottom: bottom,
      automaticallyImplyLeading: false,
      titleSpacing: titleSpacing,
      leading: showBackButton
          ? Center(
              // The PNG asset at AppImages.arrowLeftIcon has decorative
              // corner marks baked into the alpha channel that get
              // tinted along with the chevron — looks like a "black
              // border" next to the arrow. Render the system Material
              // chevron instead until a clean asset replaces it.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBackPressed ?? Navigator.of(context).pop,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: onBarColor,
                    size: Screen.getSize(28),
                  ),
                ),
              ),
            )
          : null,
      title:
          titleWidget ??
          (title != null
              ? ScrollingTitle(
                  text: title!,
                  style:
                      titleStyle ??
                      AppTypography.h6SemiBold.copyWith(color: onBarColor),
                )
              : null),
      centerTitle: centerTitle,
      actions: actions,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
