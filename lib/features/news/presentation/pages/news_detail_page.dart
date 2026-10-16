import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/news/presentation/bloc/news_detail_cubit.dart';
import 'package:nexora/features/news/presentation/widgets/news_post_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// One post in full. Opened from the panel (which hands the post over) and
/// from a news push (which fetches it). A post that has expired or been
/// deleted shows the server's "This news is no longer available."
class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'News & Updates'),
      body: BlocBuilder<NewsDetailCubit, NewsDetailState>(
        builder: (context, state) => state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _GoneState(message: message),
          loaded: (item) => Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (item.hasImage)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: NewsPostImage(
                            item: item,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: NewsPostBody(item: item),
                      ),
                    ],
                  ),
                ),
              ),
              if (item.hasAction)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    // Already marked read when the page opened.
                    child: NewsActionButton(
                      item: item,
                      onPressed: () => runNewsAction(context, item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoneState extends StatelessWidget {
  final String message;

  const _GoneState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/discover/news.png',
              height: 88,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.grey500,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.dashboard),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
