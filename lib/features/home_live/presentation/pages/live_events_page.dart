import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/home_live/data/models/home_live_session_model.dart';
import 'package:nexora/features/home_live/presentation/bloc/home_live_cubit.dart';
import 'package:nexora/features/home_live/presentation/widgets/home_live_card.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/webinar/presentation/pages/webinars_page.dart';

/// Everything happening live, in one place: course live classes and
/// webinars as two tabs. Behind the "Live Events" icon on Home, which no
/// longer carries either rail itself.
///
/// Owns its own cubits (like [WebinarsPage]) so it doesn't depend on the
/// Dashboard's.
class LiveEventsPage extends StatelessWidget {
  const LiveEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HomeLiveCubit>()..load()),
        BlocProvider(create: (_) => sl<WebinarsCubit>()..load()),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: CustomAppBar(
            title: 'Live Events',
            bottom: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.mutedTextPrimary,
              indicatorColor: AppColors.primary,
              labelStyle: AppTypography.bodyTextLargeSemiBold,
              tabs: const [
                Tab(text: 'Live Classes'),
                Tab(text: 'Webinars'),
              ],
            ),
          ),
          body: const SafeArea(
            child: TabBarView(
              children: [_LiveClassesTab(), WebinarsListView()],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveClassesTab extends StatelessWidget {
  const _LiveClassesTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeLiveCubit, HomeLiveState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (sessions, liveCount, _, __, ___, ____) =>
              _SessionList(sessions: sessions),
          error: (message) => _Empty(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            body: message,
            onRefresh: () => context.read<HomeLiveCubit>().load(),
          ),
          orElse: () => const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<HomeLiveSessionItem> sessions;

  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return _Empty(
        icon: Icons.live_tv_outlined,
        title: 'No live classes right now',
        body: 'Live and upcoming classes from your courses will show up here.',
        onRefresh: () => context.read<HomeLiveCubit>().silentRefresh(),
      );
    }

    final cardWidth = MediaQuery.of(context).size.width - 40;
    final cardHeight = HomeLiveCard.heightFor(context, cardWidth);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<HomeLiveCubit>().silentRefresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Screen.getPadding(horizontal: 20, vertical: 16),
        // Server order is authoritative — never re-sort.
        itemCount: sessions.length,
        separatorBuilder: (_, __) =>
            SizedBox(height: Screen.getVerticalSize(14)),
        itemBuilder: (_, i) => SizedBox(
          height: cardHeight,
          child: HomeLiveCard(
            key: ValueKey(sessions[i].roomId),
            session: sessions[i],
            cardWidth: cardWidth,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function() onRefresh;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: Screen.getPadding(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 64, color: AppColors.grey300),
                      SizedBox(height: Screen.getVerticalSize(14)),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.h5SemiBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: Screen.getFontSizeCapped(16),
                        ),
                      ),
                      SizedBox(height: Screen.getVerticalSize(6)),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTextLargeMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                          fontSize: Screen.getFontSize(13),
                        ),
                      ),
                    ],
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
