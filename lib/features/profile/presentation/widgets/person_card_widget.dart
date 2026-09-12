import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/bloc/theme_cubit.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/profile/data/models/user_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dark_mode_tile.dart' show ThemeModeBadge;

/// Profile header — who the learner is, and which account they're in.
///
/// Laid out as an identity row (avatar, then name over email) with the
/// account facts on a separate line beneath it. The centred-column
/// version this replaces stacked all five elements vertically, which
/// read as a list of equally-important things; identity and metadata are
/// not equally important, and the split says so.
///
/// Identical on iOS and Android — nothing here is platform-conditional.
class PersonCardWidget extends StatelessWidget {
  final UserProfileModel? profile;

  /// Opens the edit-profile screen. The pencil is only rendered when a
  /// handler is supplied, so the card stays usable read-only wherever it
  /// gets reused.
  final VoidCallback? onEdit;

  const PersonCardWidget({super.key, this.profile, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final joinedAt = profile?.joinAt;
    // Falls back to the `.env` ORG_ID when the learner never went through
    // the entity-code gate (Android, and iOS builds for a single client),
    // so this is populated on every platform rather than only where the
    // code was typed by hand.
    // `displayOrgCode`, not `effectiveOrgCode`: the latter throws when
    // `.env` hasn't loaded, and a header label must not be able to take
    // the profile screen down with it.
    final entityCode = OrgCodeService.instance.displayOrgCode
        ?.trim()
        .toUpperCase();
    final hasEntityCode = entityCode != null && entityCode.isNotEmpty;
    final hasJoined = joinedAt != null && joinedAt.isNotEmpty;

    final radius = BorderRadius.circular(AppSizes.radiusL);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        // A gradient rather than one flat alpha, so the surface has a
        // direction and reads as a panel instead of a faint rectangle.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.62),
            AppColors.white.withValues(alpha: 0.34),
          ],
        ),
        border: AppDecorations.cardBorder(
          lightColor: AppColors.alwaysWhite.withValues(alpha: 0.55),
        ),
        boxShadow: AppDecorations.cardShadow(),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              // Padding-based sizing rather than a fixed height, so the
              // card adapts to any screen (iPad, Fold, phone) without
              // overflowing.
              padding: EdgeInsets.symmetric(
                horizontal: Screen.getHorizontalSize(16),
                vertical: Screen.getVerticalSize(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identityRow(),
                  if (hasJoined || hasEntityCode) ...[
                    SizedBox(height: Screen.getVerticalSize(14)),
                    Row(
                      children: [
                        if (hasJoined)
                          Expanded(
                            child: _InfoChip(
                              label: 'Joined',
                              value: Utils.formatJoinedAtDate(joinedAt),
                            ),
                          ),
                        if (hasJoined && hasEntityCode)
                          SizedBox(width: Screen.getHorizontalSize(10)),
                        if (hasEntityCode)
                          Expanded(
                            child: _InfoChip(
                              label: 'Entity Code',
                              value: entityCode,
                              // Tap copies it — the one value here anyone
                              // ever needs to repeat, to support or to a
                              // colleague setting up their own device.
                              // Carries no copy glyph: at this chip width
                              // the icon truncated the label beside it,
                              // and a readable label matters more than
                              // advertising a secondary action.
                              onTap: () => _copyEntityCode(context, entityCode),
                            ),
                          ),
                        SizedBox(width: Screen.getHorizontalSize(10)),
                        // Light/dark toggle, sitting with the account
                        // facts rather than buried in a settings list.
                        // Owns no state — reads and writes the app-wide
                        // ThemeCubit.
                        const _ThemeToggle(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // The gilt top edge every other raised panel in the app
            // carries (see PremiumSurface).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppDecorations.topEdgeHighlight(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edge of the square avatar tile. Sized to sit within a point or two of
/// the details panel beside it — name (18pt at 1.2), email (13pt at
/// 1.25), a 3pt gap and 14pt of padding top and bottom come to ~69.
const double _avatarTile = 72;

/// The look shared by every panel inside the card — the identity block,
/// the two info chips, and the theme tile.
///
/// One place on purpose: these sit in the same card, and a fill or radius
/// that drifts on one of them is the kind of difference nobody notices
/// while writing it and everybody notices on screen.
abstract final class _Panel {
  /// A shade brighter than the card, so a panel reads as raised out of
  /// the surface rather than drawn onto it.
  static Color get fill => AppColors.white.withValues(alpha: 0.55);

  static Color get borderColor => AppColors.primary.withValues(alpha: 0.10);

  static double get radius => AppSizes.radiusM;

  static BoxDecoration decoration() => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: fill,
    border: Border.all(color: borderColor, width: 1),
  );

  /// The same thing as a [ShapeBorder], for the panels that must be a
  /// [Material] — an InkWell splash is painted by the Material it sits
  /// on, so a tappable panel has to *be* one rather than sit inside a
  /// transparent one with its own decorated child.
  static RoundedRectangleBorder shape() => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(color: borderColor, width: 1),
  );
}

/// Puts the entity code on the clipboard and says so.
///
/// Fire-and-forget: `Clipboard.setData` resolves once the platform has
/// taken the text, and there is no failure the learner could act on, so
/// the confirmation is optimistic rather than awaited-and-branched.
void _copyEntityCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  CustomSnackbar.success(
    context,
    title: 'Copied',
    message: 'Entity code $code copied to clipboard.',
    duration: const Duration(seconds: 2),
  );
}

/// Avatar + name + email, and — when [onEdit] is supplied — the whole
/// block is the tap target for editing.
///
/// **Nothing is reserved on the right for a button.** A dedicated edit
/// control would claim that column on every card, including the ones
/// where a long name and a long email need every pixel of it. The pencil
/// lives on the avatar instead, over space the picture already occupies,
/// and the tap area is the row itself.
extension on PersonCardWidget {
  Widget _identityRow() {
    final handler = onEdit;

    // Name over email, in a panel of their own. The avatar sits *beside*
    // that panel rather than inside it — it is already a shape with its
    // own ring and badge, and boxing it inside a second rounded panel
    // reads as a frame around a frame.
    Widget details = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(12),
        vertical: Screen.getVerticalSize(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile?.name ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h5SemiBold.copyWith(
              fontSize: Screen.getFontSizeCapped(18),
              height: 1.2,
            ),
          ),
          SizedBox(height: Screen.getVerticalSize(3)),
          Text(
            // Email is the identifier learners recognise; the phone
            // number stands in only for accounts that signed up
            // without one.
            profile?.email ?? profile?.phoneNumber ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyTextMedium.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: Screen.getFontSizeCapped(13),
              color: AppColors.mutedTextPrimary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );

    details = handler == null
        ? Container(decoration: _Panel.decoration(), child: details)
        // The Material *is* the panel rather than a transparent wrapper
        // around a decorated child: ink is painted by the Material, so a
        // fill drawn above it would swallow the splash.
        : Material(
            color: _Panel.fill,
            shape: _Panel.shape(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: handler, child: details),
          );

    // The avatar tile is an explicit square rather than a stretched one.
    //
    // Matching the details panel exactly would mean `IntrinsicHeight` +
    // `CrossAxisAlignment.stretch`, and that cannot work here: the avatar
    // sizes itself with a `LayoutBuilder`, which by design refuses to
    // report intrinsic dimensions, so the two throw when combined. A
    // fixed square with the row centred lands within a couple of points
    // of the panel's natural height, which is indistinguishable on screen
    // and cannot overflow.
    Widget avatarTile = Container(
      width: Screen.getSize(_avatarTile),
      height: Screen.getSize(_avatarTile),
      decoration: _Panel.decoration(),
      // The tile owns the breathing room: the avatar fills whatever
      // square is left after this padding, so the two can never drift
      // into each other.
      padding: EdgeInsets.all(Screen.getSize(6)),
      child: _Avatar(profile: profile, showEditBadge: handler != null),
    );
    if (handler != null) {
      // The pencil badge lives on the avatar, so the tile has to open the
      // editor too — otherwise the one thing that looks like the control
      // is the one thing that isn't. No ripple: the badge is the
      // affordance, and a splash under a photo is invisible anyway.
      avatarTile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handler,
        child: avatarTile,
      );
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatarTile,
        SizedBox(width: Screen.getHorizontalSize(12)),
        // Expanded, so a long name ellipsises instead of pushing the
        // row past the card edge.
        Expanded(child: details),
      ],
    );

    if (handler == null) return row;
    return Semantics(
      button: true,
      // The pencil carries no text, so the action has to be stated for
      // anyone using a screen reader.
      label: 'Edit profile',
      child: row,
    );
  }
}

/// Avatar, or the learner's initials when they haven't set a picture.
///
/// **Sizes itself from its box rather than to a constant.** It lives in a
/// tile whose height is decided by the text panel beside it, and a fixed
/// size drawn into that tile is two independent scales that eventually
/// cross: `Screen.getSize` tracks one axis, the tile height tracks font
/// metrics and padding on another, and on a short viewport the circle
/// grows straight through the tile's corners. Reading the box removes the
/// question — the picture cannot outgrow what it is drawn inside.
///
/// The constant below is only the fallback for an unbounded parent.
///
/// Carries the edit pencil as a corner badge when [showEditBadge] is on.
/// The badge is decoration, not a button — the tile is the tap target, so
/// the pencil never has to be hit precisely.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, this.showEditBadge = false});

  final UserProfileModel? profile;
  final bool showEditBadge;

  /// Used only where the parent imposes no bounds.
  static const double _fallbackSize = 58;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final edge = constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? math.min(constraints.maxWidth, constraints.maxHeight)
            : Screen.getSize(_fallbackSize);
        return _build(edge);
      },
    );
  }

  Widget _build(double edge) {
    final image = profile?.userProfileImage;
    final hasImage = image != null && image.isNotEmpty;

    final avatar = Container(
      width: edge,
      height: edge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Ring around the picture. Photos users upload are arbitrary — a
        // pale sky or a white wall bleeds straight into the tile without
        // an edge to stop it.
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 2,
        ),
        image: hasImage
            ? DecorationImage(
                image: CachedNetworkImageProvider(
                  image,
                  // Presigned URLs change on every fetch; the stripped
                  // key is what stops the same picture being
                  // re-downloaded each time.
                  cacheKey: Utils.imageCacheKey(image),
                ),
                fit: BoxFit.cover,
              )
            : null,
        gradient: hasImage
            ? null
            : LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.6),
                  AppColors.primary.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              Utils.getInitials(profile?.name ?? '?'),
              style: AppTypography.h6SemiBold.copyWith(
                color: AppColors.alwaysWhite,
                // Proportional too, for the same reason as the badge.
                fontSize: edge * 0.36,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
    );

    if (!showEditBadge) return avatar;

    // A fraction of the circle rather than a fixed size, so the badge
    // keeps its proportions at every tile size.
    final badge = edge * 0.36;
    return SizedBox(
      width: edge,
      height: edge,
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                // A ring in the card's own surface colour, so the badge
                // reads as sitting on top of the photo rather than being
                // part of it.
                border: Border.all(color: AppColors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.edit_rounded,
                size: badge * 0.52,
                color: AppColors.alwaysWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sun / moon toggle for the app theme.
///
/// Reuses [ThemeModeBadge] — the same control the settings list used —
/// so the two can't drift apart visually. The badge is decorative by
/// default and takes the gesture here, since on this card there is no
/// surrounding row to own the tap.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        // Not `mode == ThemeMode.dark`: under ThemeMode.system the truth
        // is the platform brightness, and a sun on a dark screen would
        // be plainly wrong.
        final isDark = mode.isDarkIn(context);
        return Semantics(
          button: true,
          label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: ThemeModeBadge(
            isDark: isDark,
            // The same fill, radius and height as the info chips beside
            // it, so the meta row reads as one set of controls rather
            // than two panels and a token. The accent survives in the
            // rim, the glow and the glyph, which is what still marks
            // this one out as the theme switch.
            backgroundColor: _Panel.fill,
            borderRadius: BorderRadius.circular(_Panel.radius),
            // Matches a chip's rendered height: 9pt padding top and
            // bottom, an 10.5pt label at 1.1, a 2pt gap and a 13pt value
            // at 1.15. Stated as a constant rather than measured with an
            // IntrinsicHeight, which would cost a second layout pass on
            // every profile build to arrive at the same number.
            size: 46,
            onTap: () =>
                context.read<ThemeCubit>().toggle(isCurrentlyDark: isDark),
          ),
        );
      },
    );
  }
}

/// One account fact, as a filled chip.
///
/// Chips rather than bare label/value pairs because the row was mostly
/// empty otherwise: two short strings floating in a wide card with a lone
/// badge stranded at the right edge. A chip that stretches to fill its
/// share of the row gives the values a container to sit in, and the row
/// stops reading as unfinished.
///
/// **No glyphs, leading or trailing.** Both were tried and removed: at
/// two chips per row they cost ~42pt of a ~133pt content width, enough to
/// truncate the label and the value together ("Entity Co…", "22, May
/// 20…"). The label already says what the value is, so the decoration was
/// paying for nothing, and a legible label beats advertising a secondary
/// action.
///
/// [onTap] makes the chip interactive — used by the entity code, which
/// copies itself. A chip with no handler is inert and shows no
/// affordance.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: Screen.getHorizontalSize(10),
        vertical: Screen.getVerticalSize(9),
      ),
      decoration: _Panel.decoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextMedium.copyWith(
                    fontSize: Screen.getFontSizeCapped(10.5),
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedTextPrimary,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(2)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextMedium.copyWith(
                    fontSize: Screen.getFontSizeCapped(13),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final handler = onTap;
    if (handler == null) return body;

    return Material(
      // Transparent, not the card's own surface: the card paints a
      // translucent decoration and ink splashing behind it is invisible.
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: handler, child: body),
    );
  }
}
