import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/store/domain/usecases/store_catalog_usecases.dart';
import 'package:nexora/features/store/presentation/bloc/store_reviews_cubit.dart';
import 'package:nexora/features/store/presentation/widgets/store_review_tile.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Every approved review comment on a product (C5). The rating summary on
/// the product page counts every rating; this lists the comments only.
class StoreReviewsPage extends StatelessWidget {
  final String productId;
  final String? title;

  const StoreReviewsPage({super.key, required this.productId, this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoreReviewsCubit(
        getReviewsUseCase: sl<GetStoreReviewsUseCase>(),
        productId: productId,
      )..load(),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        appBar: const CustomAppBar(title: 'Reviews'),
        body: BlocBuilder<StoreReviewsCubit, StoreReviewsState>(
          builder: (context, state) {
            final cubit = context.read<StoreReviewsCubit>();
            if (state.loading) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: StoreSkeletonBox(height: 96, radius: 16),
                  ),
                ),
              );
            }
            if (state.error != null && state.items.isEmpty) {
              return StoreErrorView(message: state.error!, onRetry: cubit.load);
            }
            if (state.items.isEmpty) {
              return const StoreEmptyState(
                icon: Icons.forum_outlined,
                title: 'No written reviews yet',
                message:
                    'Star ratings count straight away; comments appear here '
                    'once the seller has checked them.',
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (n) => storeOnScrollEnd(n, cubit.loadMore),
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: cubit.load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  itemCount: state.items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == state.items.length) {
                      return state.loadingMore
                          ? const StoreLoadMoreIndicator()
                          : const SizedBox.shrink();
                    }
                    return StorePanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StoreReviewTile(review: state.items[i]),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
