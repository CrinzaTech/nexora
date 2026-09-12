import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

/// App-wide toast: a compact frosted-glass card that drops in from the
/// top and leaves the same way.
///
/// **Top-anchored, and deliberately an [OverlayEntry] rather than a
/// [SnackBar].** `ScaffoldMessenger` only ever animates from the bottom
/// edge, so a top entrance is not something it can be configured into.
/// Going through the root overlay also means the toast floats above
/// bottom sheets and dialogs — several call sites fire from inside the
/// enrolment and plan sheets, and a `SnackBar` would have been buried
/// under them.
///
/// The public API is unchanged from the previous
/// `awesome_snackbar_content` implementation, so all existing call sites
/// keep working:
///
/// ```dart
/// CustomSnackbar.success(context, title: 'Done', message: 'Profile updated');
/// CustomSnackbar.error(context, title: 'Oops', message: 'Something went wrong');
/// CustomSnackbar.warning(context, title: 'Warning', message: 'Low storage');
/// CustomSnackbar.info(context, title: 'Info', message: 'New update available');
/// ```
class CustomSnackbar {
  CustomSnackbar._();

  /// The toast currently on screen, if any. Only one is ever shown — a
  /// second call replaces the first rather than stacking, which is what
  /// the old `hideCurrentSnackBar()` call did.
  static OverlayEntry? _entry;
  static GlobalKey<_GlassToastState>? _key;

  static void success(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      accent: AppColors.success,
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      title: title,
      message: message,
      accent: AppColors.error,
      icon: Icons.error_rounded,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      accent: AppColors.warning,
      icon: Icons.warning_amber_rounded,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      title: title,
      message: message,
      accent: AppColors.primary,
      icon: Icons.info_rounded,
      duration: duration,
    );
  }

  /// Animates the current toast away, if one is showing. Safe to call
  /// when nothing is on screen.
  static void dismiss() => _key?.currentState?.close();

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required Color accent,
    required IconData icon,
    required Duration duration,
  }) {
    // `maybeOf` rather than `of`: a call fired from a widget already torn
    // off the tree should be a no-op, not a crash. Several call sites run
    // after an await and guard with `mounted`, but not all of them do.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Drop any existing toast instantly. Animating the old one out while
    // the new one drops in reads as a stutter, and the replacement is
    // usually the more urgent message.
    _removeCurrent();

    final key = GlobalKey<_GlassToastState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlassToast(
        key: key,
        title: title,
        message: message,
        accent: accent,
        icon: icon,
        duration: duration,
        onFinished: () {
          // Guard against removing an entry that a newer toast already
          // replaced — otherwise the new toast's entry is the one that
          // gets torn down when the old one finishes animating.
          if (identical(_entry, entry)) _removeCurrent();
        },
      ),
    );

    _entry = entry;
    _key = key;
    overlay.insert(entry);
  }

  static void _removeCurrent() {
    _entry?.remove();
    _entry = null;
    _key = null;
  }
}

/// The card itself: frosted, tinted with [accent], and animated in and
/// out along the top edge.
class _GlassToast extends StatefulWidget {
  const _GlassToast({
    super.key,
    required this.title,
    required this.message,
    required this.accent,
    required this.icon,
    required this.duration,
    required this.onFinished,
  });

  final String title;
  final String message;
  final Color accent;
  final IconData icon;

  /// How long the toast stays before dismissing itself.
  final Duration duration;

  /// Called once the exit animation has finished and the entry can be
  /// torn down.
  final VoidCallback onFinished;

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;

  /// Latches on the first close so a swipe, a tap on the X and the
  /// auto-dismiss timer landing together can't each start a reverse.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      // Leaving is quicker than arriving: an entrance wants to be
      // noticed, an exit wants to be out of the way.
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slide =
        Tween<Offset>(
          // Starts one full card-height above its resting place, so it
          // slides out from behind the status bar rather than fading in
          // on the spot.
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
    _timer = Timer(widget.duration, close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Plays the exit animation, then hands back to [CustomSnackbar] to
  /// remove the overlay entry.
  void close() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Screen.getHorizontalSize(14),
            Screen.getVerticalSize(8),
            Screen.getHorizontalSize(14),
            0,
          ),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  // Keeps the card from stretching the full width of a
                  // tablet, where a 1000pt-wide toast looks like a banner.
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: GestureDetector(
                    // Flick up to dismiss — the same direction it leaves
                    // in, so the gesture and the animation agree.
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -80) close();
                    },
                    child: _card(accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The frosted panel.
  ///
  /// **Neutral glass, not a coloured block.** The fill is the app's own
  /// surface colour at low opacity, so what tints the card is whatever
  /// it happens to be sitting over — that is what separates real glass
  /// from a translucent rectangle. [accent] survives as a faint wash and,
  /// mainly, as the colour of the glyph in the white chip: an error still
  /// has to be distinguishable from a success at a glance, which the
  /// purely neutral panels this is modelled on never had to solve.
  ///
  /// Text is dark-on-light here rather than white-on-colour, and both
  /// the surface and the text read from theme-aware [AppColors] getters,
  /// so the whole card inverts correctly in dark mode.
  static const double _radius = 22;

  Widget _card(Color accent) {
    // `Material` is not decoration here — an OverlayEntry sits outside
    // the app's Material ancestry, and unparented `Text` falls back to
    // Flutter's debug style: discoloured glyphs with a double underline.
    // A transparent Material re-establishes the DefaultTextStyle that
    // suppresses it. (The styles below also set `TextDecoration.none`
    // outright, so nothing can reintroduce the underline.)
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          // The heavy blur is the whole effect. It only shows because
          // the fill above it is genuinely translucent — at the
          // near-opaque alphas this started with, the blur did no
          // visible work and the card read as flat paint.
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              // Sheen: a soft highlight raking across the top-left and
              // gone by the middle. Real glass catches light unevenly.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.alwaysWhite.withValues(alpha: 0.20),
                  AppColors.alwaysWhite.withValues(alpha: 0.06),
                  AppColors.alwaysWhite.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Tinted at both corners, clearest through the middle —
                // the accent reads around the edges while the centre
                // stays the most see-through part of the card.
                //
                // Every colour is blended opaque *first* and only then
                // made translucent: tinting a colour that is already
                // translucent just thins the accent instead of shifting
                // the hue.
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.34),
                    AppColors.white,
                  ).withValues(alpha: 0.60),
                  AppColors.white.withValues(alpha: 0.46),
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.28),
                    AppColors.white,
                  ).withValues(alpha: 0.56),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              // Tinted rather than plain white. A white hairline is
              // invisible against the app's own light surfaces, which is
              // exactly why the edge couldn't be seen; a pale red one
              // reads against both a light page and a dark thumbnail.
              border: Border.all(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.55),
                  AppColors.alwaysWhite,
                ).withValues(alpha: 0.90),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -6,
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Screen.getHorizontalSize(12),
              vertical: Screen.getVerticalSize(12),
            ),
            child: Row(
              children: [
                _iconChip(accent),
                SizedBox(width: Screen.getHorizontalSize(12)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextLargeSemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: Screen.getFontSizeCapped(15),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.02,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: Screen.getVerticalSize(2)),
                      Text(
                        widget.message,
                        // Capped rather than unbounded: a toast that
                        // grows to six lines stops being a toast.
                        // Anything longer belongs in a dialog.
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextMedium.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.74),
                          fontSize: Screen.getFontSizeCapped(13),
                          height: 1.35,
                          letterSpacing: -0.01,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(8)),
                _closeButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Solid white disc with the accent-coloured glyph — the one opaque
  /// element on the card, which is what lets it read against a busy
  /// backdrop where a bare icon would disappear.
  Widget _iconChip(Color accent) {
    final size = Screen.getSize(38);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(widget.icon, color: accent, size: Screen.getSize(20)),
    );
  }

  Widget _closeButton() {
    // A comfortable tap target around a deliberately quiet glyph — the
    // dismiss affordance shouldn't compete with the message.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: close,
      child: Padding(
        padding: EdgeInsets.all(Screen.getSize(6)),
        child: Icon(
          Icons.close_rounded,
          color: AppColors.textPrimary.withValues(alpha: 0.45),
          size: Screen.getSize(17),
        ),
      ),
    );
  }
}
