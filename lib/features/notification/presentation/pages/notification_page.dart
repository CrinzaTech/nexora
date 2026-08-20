import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexora/features/notification/data/models/notification_model.dart';
import 'package:nexora/features/notification/presentation/bloc/notification_cubit.dart';
import 'package:nexora/features/notification/presentation/bloc/notification_state.dart';

/// Notification Screen
/// Displays user notifications and alerts
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return Scaffold(
      appBar: CustomAppBar(title: 'Notifications'),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          return state.when(
            initial: () => const SizedBox.shrink(),
            loading: () => const _NotificationListShimmer(),
            loaded: (notifications) {
              if (notifications.isEmpty) {
                return _EmptyState();
              }
              return _NotificationList(notifications: notifications);
            },
            error: (message) => _ErrorState(message: message),
          );
        },
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppImages.notificationIcon,
            height: 80,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            color: AppColors.mutedTextPrimary,
          ),

          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingL).top),
          Text(
            'No Notifications',
            style: AppTypography.h5SemiBold.copyWith(color: AppColors.grey500),
          ),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingS).top),
          Text(
            'You\'re all caught up!',
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingL).top),
          const Text('Something went wrong'),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingS).top),
          Text(message),
          SizedBox(height: Screen.getPadding(vertical: AppSizes.paddingL).top),
          ElevatedButton(
            onPressed: () {
              context.read<NotificationCubit>().loadNotifications();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Notification list widget
class _NotificationList extends StatelessWidget {
  final List<NotificationModel> notifications;

  const _NotificationList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<NotificationCubit>().refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1.5),
        padding: Screen.getPadding(horizontal: AppSizes.paddingM),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _NotificationCard(notification: notification);
        },
      ),
    );
  }
}

/// Notification card widget
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final iconBg = isUnread
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.mutedTextPrimary.withValues(alpha: 0.15);
    final iconColor = isUnread ? AppColors.primary : AppColors.mutedTextPrimary;

    // Wrap in a transparent Material so the InkWell paints its ripple
    // against this surface (otherwise the closest Material is the
    // Scaffold's, which leaves the splash unclipped and feeling
    // detached from the row). `borderRadius` on the InkWell then clips
    // the splash + highlight into a rounded rectangle, so the ripple
    // stays inside the row even though the card has no visible border.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tapping a notification (a) fires the read-status PUT — the cubit
        // does an optimistic flip first so the dot disappears immediately
        // — and (b) routes based on notificationType. Already-read items
        // short-circuit the PUT inside the cubit so we don't spam it.
        onTap: () => _handleTap(context, notification),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        // Subtle primary-tinted ripple + hover state — softer than
        // Material's default grey splash.
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Padding(
          // No fixed height — the row grows with the message so long
          // notifications wrap onto multiple lines instead of being
          // clipped.
          padding: Screen.getPadding(vertical: AppSizes.paddingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar: backend image when present, tinted bell icon
              // otherwise. CustomNetworkImage falls back to errorWidget
              // for both null/empty URLs and load failures, so a single
              // ClipOval covers all three cases.
              ClipOval(
                child: CustomNetworkImage(
                  url: notification.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: _NotificationIconAvatar(
                    iconBg: iconBg,
                    iconColor: iconColor,
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(10)),

              // Title + message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        fontSize: Screen.getFontSize(16),
                      ),
                    ),

                    // Backend may ship markdown in the message (bold, lists,
                    // links). MarkdownBody renders inline without owning its
                    // own scroll, so it slots into the surrounding Column
                    // exactly where the old Text widget sat. Paragraph text
                    // styling is forced to match the original `Text` style
                    // so unstyled messages look identical to before; bold /
                    // italic / link styles inherit from MarkdownStyleSheet's
                    // defaults derived from the ambient theme.
                    MarkdownBody(
                      data: notification.message,
                      softLineBreak: true,
                      // Links route through the same launcher used elsewhere
                      // in this file — keeps in-line URLs tappable and
                      // outside the app.
                      onTapLink: (text, href, title) {
                        if (href != null && href.isNotEmpty) {
                          _openExternal(context, href);
                        }
                      },
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            // p == paragraph; matches the prior bodyTextMedium
                            // muted look so plain-text messages render
                            // pixel-identical to the pre-markdown version.
                            p: AppTypography.bodyTextMedium.copyWith(
                              fontWeight: FontWeight.w400,
                              fontSize: Screen.getFontSize(14),
                              color: AppColors.mutedTextPrimary,
                            ),
                            // Strip the default block margins so a one-line
                            // message doesn't gain extra spacing relative to
                            // a plain Text.
                            pPadding: EdgeInsets.zero,
                            blockSpacing: 4,
                            a: AppTypography.bodyTextMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: Screen.getFontSize(14),
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),

              // Trailing column: unread dot above the timestamp
              Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  // SizedBox(height: Screen.getVerticalSize(8)),
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: AppTypography.bodyTextMedium.copyWith(
                      fontSize: Screen.getFontSize(12),
                      color: AppColors.mutedTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mark-as-read fires for every tap; then we branch on [NotificationType]
  /// to navigate. Unknown types and parse failures are silently dropped
  /// to mark-as-read only — never crash the page over a bad payload.
  static void _handleTap(BuildContext context, NotificationModel n) {
    context.read<NotificationCubit>().markAsRead(n.id);
    final ref = n.referenceValue?.trim() ?? '';
    switch (n.notificationType) {
      case NotificationType.course:
        final courseId = int.tryParse(ref);
        if (courseId == null) return;
        context.push('${AppRoutes.courseDetail}?courseId=$courseId');
        return;
      case NotificationType.category:
        final categoryId = int.tryParse(ref);
        if (categoryId == null) return;
        // Category route accepts categoryId + a title; the notification
        // doesn't ship a title so we fall back to the route's default.
        context.push(
          '${AppRoutes.catalog}?categoryId=$categoryId'
          '&title=${Uri.encodeComponent(n.title)}',
        );
        return;
      case NotificationType.externalLink:
        if (ref.isEmpty) return;
        _openExternal(context, ref);
        return;
      case NotificationType.none:
        return;
    }
  }

  /// Fire-and-forget URL launch. Surface a single snackbar on failure so
  /// the user knows the tap didn't silently do nothing.
  static Future<void> _openExternal(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      CustomSnackbar.error(context, title: 'Could not open link', message: raw);
    }
  }

  /// Today → "10:50 AM" · Yesterday → "Yesterday" · Older → "12 Apr".
  static String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(date.year, date.month, date.day);
    if (dDay == today) {
      final hour12 = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour12:$minute $period';
    }
    if (dDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

/// Tinted circle + bell glyph — the original avatar visual. Used as the
/// CustomNetworkImage errorWidget so it shows up for notifications with
/// no imageUrl set AND for ones whose URL fails to load.
class _NotificationIconAvatar extends StatelessWidget {
  final Color iconBg;
  final Color iconColor;

  const _NotificationIconAvatar({
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Image.asset(
        AppImages.notificationIcon,
        height: 25,
        width: 25,
        color: iconColor,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Shimmer placeholder list shown while notifications are loading.
class _NotificationListShimmer extends StatelessWidget {
  const _NotificationListShimmer();

  static const _placeholderCount = 8;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: Screen.getPadding(all: AppSizes.paddingM),
      itemCount: _placeholderCount,
      separatorBuilder: (_, __) => const Divider(height: 1.5),
      itemBuilder: (_, index) {
        // Vary the title bar width slightly so the placeholders feel organic.
        final titleWidth = Screen.getHorizontalSize(
          140 + (index.isEven ? 30 : 0),
        );
        return _NotificationCardShimmer(titleWidth: titleWidth);
      },
    );
  }
}

/// Shimmer placeholder mirroring the [_NotificationCard] layout.
class _NotificationCardShimmer extends StatelessWidget {
  final double titleWidth;

  const _NotificationCardShimmer({required this.titleWidth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Screen.getPadding(vertical: AppSizes.paddingS),
      child: Shimmer.fromColors(
        baseColor: AppColors.grey200.withValues(alpha: 0.6),
        highlightColor: AppColors.white.withValues(alpha: 0.9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular icon placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(12)),

            // Title + message bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: titleWidth,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SizedBox(height: Screen.getVerticalSize(8)),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(8)),

            // Trailing dot + timestamp placeholder
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: Screen.getVerticalSize(8)),
                Container(
                  width: Screen.getHorizontalSize(48),
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
