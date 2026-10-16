import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/presentation/bloc/news_home_cubit.dart';
import 'package:nexora/features/news/presentation/bloc/news_list_cubit.dart';
import 'package:nexora/features/news/presentation/widgets/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

/// The News & Updates panel, opened from the Discover row's News icon.
/// Every live post, newest first, paged with infinite scroll.
class NewsUpdatesPage extends StatefulWidget {
  const NewsUpdatesPage({super.key});

  @override
  State<NewsUpdatesPage> createState() => _NewsUpdatesPageState();
}

class _NewsUpdatesPageState extends State<NewsUpdatesPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<NewsListCubit>().load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    // The badge is already lowered locally; this squares it with the
    // server for when the learner lands back on Home.
    sl<NewsHomeCubit>().refresh();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<NewsListCubit>().loadMore();
    }
  }

  void _open(NewsItem item) {
    final read = context.read<NewsListCubit>().open(item);
    context.push('${AppRoutes.newsDetail}?newsId=${item.newsId}', extra: read);
  }

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    final unread = context.select<NewsHomeCubit, int>(
      (c) => c.state.unreadCount,
    );
    final hasItems = context.select<NewsListCubit, bool>(
      (c) => c.state.maybeWhen(
        loaded: (items, _) => items.isNotEmpty,
        orElse: () => false,
      ),
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'News & Updates',
        actions: [
          if (unread > 0 && hasItems)
            TextButton(
              onPressed: () => context.read<NewsListCubit>().markAllRead(),
              child: Text(
                'Mark all as read',
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                  fontSize: Screen.getFontSizeCapped(13),
                ),
              ),
            ),
        ],
      ),
      body: BlocBuilder<NewsListCubit, NewsListState>(
        builder: (context, state) => state.when(
          initial: () => const SizedBox.shrink(),
          loading: () => const _NewsListShimmer(),
          error: (message) => _ErrorState(
            message: message,
            onRetry: () => context.read<NewsListCubit>().load(),
          ),
          loaded: (items, page) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<NewsListCubit>().refresh(),
            child: items.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      Screen.getHorizontalSize(AppSizes.paddingM),
                      12,
                      Screen.getHorizontalSize(AppSizes.paddingM),
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: items.length + (page.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= items.length) return const _MoreSpinner();
                      final item = items[index];
                      return NewsCard(item: item, onTap: () => _open(item));
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _MoreSpinner extends StatelessWidget {
  const _MoreSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

/// Inside a scrollable so pull-to-refresh still works on an empty panel.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/discover/news.png',
                    height: 96,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No news right now. Check back later.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTypography.h6SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _NewsListShimmer extends StatelessWidget {
  const _NewsListShimmer();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Shimmer.fromColors(
      baseColor: AppColors.grey200.withValues(alpha: 0.6),
      highlightColor: AppColors.white.withValues(alpha: 0.9),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: Screen.getPadding(all: AppSizes.paddingM),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 22),
        itemBuilder: (_, i) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(56, 16),
                  const SizedBox(height: 8),
                  bar(i.isEven ? 200 : 160, 14),
                  const SizedBox(height: 8),
                  bar(double.infinity, 12),
                  const SizedBox(height: 6),
                  bar(80, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
