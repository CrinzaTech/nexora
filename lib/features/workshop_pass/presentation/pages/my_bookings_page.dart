import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/workshop_pass/data/models/my_webinar_model.dart';
import 'package:nexora/features/workshop_pass/presentation/bloc/my_webinars_cubit.dart';
import 'package:nexora/features/workshop_pass/presentation/workshop_pass_entry.dart';

/// My Bookings: every webinar and workshop this learner signed up for.
///
/// **This screen exists so a pass can be found again.** The pass
/// endpoints are keyed on a workshop's slug, which the app only holds
/// for as long as the purchase is on screen. Without a list, a pass is
/// reachable in the minutes after buying and never afterwards, which is
/// precisely backwards: the day it matters is the day of the event.
///
/// A history, not a schedule. Cancelled and long-finished events are
/// here too, and so is every platform, not only workshops.
class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<MyWebinarsCubit>()..load(),
      child: const _MyBookingsView(),
    );
  }
}

class _MyBookingsView extends StatelessWidget {
  const _MyBookingsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(title: 'My Bookings', centerTitle: true),
        body: SafeArea(
          child: BlocBuilder<MyWebinarsCubit, MyWebinarsState>(
            builder: (context, state) {
              return state.maybeWhen(
                loaded: (webinars, page) => _Loaded(
                  webinars: webinars,
                  page: page,
                ),
                error: (message) => _ErrorView(message: message),
                orElse: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  final List<MyWebinar> webinars;
  final MyWebinarPage page;

  const _Loaded({required this.webinars, required this.page});

  @override
  Widget build(BuildContext context) {
    if (page.total == 0) return const _EmptyView();

    // Split locally, but label from the server's whole-history totals:
    // the counts have to be right on page one, and a count of what
    // happens to be loaded would climb as the learner scrolls.
    final upcoming = webinars.where((w) => !w.isPast).toList();
    final past = webinars.where((w) => w.isPast).toList();

    return Column(
      children: [
        Container(
          color: AppColors.white,
          child: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedTextPrimary,
            indicatorColor: AppColors.primary,
            labelStyle: AppTypography.bodyTextLargeSemiBold.copyWith(
              fontSize: Screen.getFontSize(14),
            ),
            tabs: [
              Tab(text: 'Upcoming (${page.upcomingCount})'),
              Tab(text: 'Past (${page.pastCount})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _BookingList(
                webinars: upcoming,
                page: page,
                emptyText: 'Nothing coming up. Anything you book will '
                    'appear here.',
              ),
              _BookingList(
                webinars: past,
                page: page,
                emptyText: 'Nothing here yet. Events you have attended '
                    'will appear here afterwards.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<MyWebinar> webinars;
  final MyWebinarPage page;
  final String emptyText;

  const _BookingList({
    required this.webinars,
    required this.page,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<MyWebinarsCubit>().refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Paging is driven by `hasMore` and nothing else.
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 300) {
            context.read<MyWebinarsCubit>().loadMore();
          }
          return false;
        },
        child: webinars.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: Screen.getVerticalSize(80)),
                  Padding(
                    padding: Screen.getPadding(horizontal: 40),
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextLargeMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                        fontSize: Screen.getFontSize(13),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Screen.getPadding(horizontal: 16, vertical: 16),
                itemCount: webinars.length + (page.hasMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    SizedBox(height: Screen.getVerticalSize(12)),
                itemBuilder: (context, index) {
                  if (index >= webinars.length) {
                    return Padding(
                      padding: Screen.getPadding(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: Screen.getSize(20),
                          height: Screen.getSize(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  return _BookingCard(webinar: webinars[index]);
                },
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final MyWebinar webinar;

  const _BookingCard({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(all: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: SizedBox(
                  width: Screen.getSize(72),
                  height: Screen.getSize(54),
                  child: CustomNetworkImage(
                    url: webinar.thumbnailUrl,
                    width: Screen.getSize(72),
                    height: Screen.getSize(54),
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.video_camera_front_outlined,
                        size: Screen.getSize(20),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      webinar.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: Screen.getFontSize(14),
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: Screen.getVerticalSize(4)),
                    Text(
                      _whenLabel(webinar),
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                        fontSize: Screen.getFontSize(12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              _PlatformBadge(webinar: webinar),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(10)),
          _StatusLine(webinar: webinar),
          if (_hasAction(webinar)) ...[
            SizedBox(height: Screen.getVerticalSize(10)),
            Align(alignment: Alignment.centerRight, child: _Action(webinar: webinar)),
          ],
        ],
      ),
    );
  }

  /// A cancelled event gets no actions at all: there is nowhere to go
  /// and nothing to show at a door.
  static bool _hasAction(MyWebinar w) {
    if (w.isCancelled) return false;
    return w.hasPass || (!w.isPast && w.hasJoinLink);
  }

  static String _whenLabel(MyWebinar w) {
    final local = w.scheduledAtLocal;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour12:$minute $meridiem';
  }
}

/// Cancelled, or whether they turned up.
///
/// **`attended` is nullable and null is not false.** A Zoom or Meet
/// meeting happens somewhere we cannot observe, and a workshop sold
/// without a managed door issues passes nobody was appointed to scan, so
/// for both there is genuinely no answer. Saying "did not attend" there
/// would tell somebody who did attend that they missed it.
class _StatusLine extends StatelessWidget {
  final MyWebinar webinar;

  const _StatusLine({required this.webinar});

  @override
  Widget build(BuildContext context) {
    if (webinar.isCancelled) {
      return _Chip(
        icon: Icons.event_busy_rounded,
        color: AppColors.error,
        text: 'Cancelled',
      );
    }

    if (webinar.isLive) {
      return _Chip(
        icon: Icons.sensors_rounded,
        color: AppColors.error,
        text: 'Live now',
      );
    }

    if (!webinar.isPast) {
      return _Chip(
        icon: Icons.schedule_rounded,
        color: AppColors.primary,
        text: 'Upcoming',
      );
    }

    final label = AttendanceLabel.of(webinar);
    final (icon, color) = switch (label) {
      AttendanceLabel.attended => (
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      AttendanceLabel.didNotAttend => (
        Icons.remove_circle_outline_rounded,
        AppColors.mutedTextPrimary,
      ),
      AttendanceLabel.notRecorded => (
        Icons.help_outline_rounded,
        AppColors.mutedTextPrimary,
      ),
    };

    return Row(
      children: [
        _Chip(icon: icon, color: color, text: label.text),
        if (webinar.passNo != null) ...[
          SizedBox(width: Screen.getHorizontalSize(8)),
          Flexible(
            child: Text(
              webinar.passNo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(11),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Chip({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Screen.getSize(13), color: color),
          SizedBox(width: Screen.getHorizontalSize(5)),
          Text(
            text,
            style: AppTypography.bodyTextSemiBold.copyWith(
              color: color,
              fontSize: Screen.getFontSize(11),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final MyWebinar webinar;

  const _PlatformBadge({required this.webinar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Screen.getPadding(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Text(
        // Written by the server, so a platform added later names itself
        // without a client release.
        webinar.platformName,
        style: AppTypography.bodyTextSemiBold.copyWith(
          color: AppColors.mutedTextPrimary,
          fontSize: Screen.getFontSize(10),
        ),
      ),
    );
  }
}

/// One action per row, in priority order.
///
/// **Gated on `hasPass`, never on `isWorkshop`.** A workshop that was
/// free, or one the learner registered for without buying, issues no
/// pass, and calling the pass endpoint for it answers 402 or 409.
class _Action extends StatelessWidget {
  final MyWebinar webinar;

  const _Action({required this.webinar});

  @override
  Widget build(BuildContext context) {
    if (webinar.hasPass) {
      return _ActionButton(
        icon: Icons.confirmation_number_outlined,
        label: 'View pass',
        filled: true,
        onTap: () => openWorkshopPass(
          context,
          slug: webinar.slug,
          workshopTitle: webinar.title,
        ),
      );
    }

    return _ActionButton(
      icon: webinar.isVenue ? Icons.map_outlined : Icons.open_in_new_rounded,
      label: webinar.isVenue ? 'Directions' : 'Join',
      filled: false,
      onTap: () => _open(context, webinar.venueOrJoinUrl!),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      CustomSnackbar.error(
        context,
        title: 'Cannot open link',
        message: 'Nothing on this device could open it.',
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: Screen.getPadding(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: Screen.getSize(15),
              color: filled ? AppColors.alwaysWhite : AppColors.primary,
            ),
            SizedBox(width: Screen.getHorizontalSize(6)),
            Text(
              label,
              style: AppTypography.bodyTextSemiBold.copyWith(
                color: filled ? AppColors.alwaysWhite : AppColors.primary,
                fontSize: Screen.getFontSize(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing booked. A perfectly normal 200, not an error.
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: Screen.getSize(60),
              color: AppColors.grey300,
            ),
            SizedBox(height: Screen.getVerticalSize(14)),
            Text(
              'No bookings yet',
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSizeCapped(16),
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(6)),
            Text(
              'Webinars and workshops you sign up for will appear here, '
              'along with your entry pass.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: Screen.getSize(56),
              color: AppColors.error,
            ),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(13),
                height: 1.45,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(16)),
            TextButton(
              onPressed: () => context.read<MyWebinarsCubit>().load(),
              child: Text(
                'Try again',
                style: AppTypography.bodyTextLargeSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
