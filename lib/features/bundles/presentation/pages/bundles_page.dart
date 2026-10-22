import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/config/payment_policy.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/presentation/bloc/bundles_cubit.dart';
import 'package:nexora/features/bundles/presentation/widgets/bundle_tile.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// Every bundle on sale — the list behind Home's "View All" (B1).
///
/// Its own [BundlesCubit], so paging here doesn't swell the Home rail.
class BundlesPage extends StatelessWidget {
  const BundlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CustomAppBar(title: 'Course Bundles'),
      body: SafeArea(
        child: !PaymentPolicy.allowsPurchases
            ? const StoreEmptyState(
                icon: Icons.layers_outlined,
                title: 'Not available',
                message: PaymentPolicy.unavailableMessage,
              )
            : BlocProvider(
                create: (_) => sl<BundlesCubit>()..load(),
                child: BlocBuilder<BundlesCubit, BundlesState>(
                  builder: (context, state) => state.maybeWhen(
                    loaded: (bundles, _, hasMore, _, isLoadingMore) =>
                        _BundleList(
                          bundles: bundles,
                          hasMore: hasMore,
                          isLoadingMore: isLoadingMore,
                        ),
                    error: (message) => StoreErrorView(
                      message: message,
                      onRetry: () => context.read<BundlesCubit>().load(),
                    ),
                    orElse: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
      ),
    );
  }
}

class _BundleList extends StatelessWidget {
  final List<BundleCard> bundles;
  final bool hasMore;
  final bool isLoadingMore;

  const _BundleList({
    required this.bundles,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BundlesCubit>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: cubit.silentRefresh,
      child: bundles.isEmpty
          ? ListView(
              // Scrollable so pull-to-refresh still works when empty.
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                StoreEmptyState(
                  icon: Icons.layers_outlined,
                  title: 'No bundles yet',
                  message: 'Course bundles from your educator will show here.',
                ),
              ],
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (hasMore && n.metrics.extentAfter < 400) cubit.loadMore();
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: bundles.length + (isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i >= bundles.length) {
                    return const StoreLoadMoreIndicator();
                  }
                  return BundleTile(
                    key: ValueKey(bundles[i].bundleId),
                    bundle: bundles[i],
                  );
                },
              ),
            ),
    );
  }
}
