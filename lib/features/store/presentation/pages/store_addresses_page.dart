import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/store/data/models/store_address_model.dart';
import 'package:nexora/features/store/presentation/bloc/store_addresses_cubit.dart';
import 'package:nexora/features/store/presentation/widgets/store_address_card.dart';
import 'package:nexora/features/store/presentation/widgets/store_sheets.dart';
import 'package:nexora/features/store/presentation/widgets/store_widgets.dart';

/// The address book (A2 / A5 / A6). In [selectMode] a tap picks the
/// delivery address and pops with it.
class StoreAddressesPage extends StatelessWidget {
  final bool selectMode;
  final int? selectedId;

  const StoreAddressesPage({
    super.key,
    this.selectMode = false,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StoreAddressesCubit>()..load(),
      child: _AddressesView(selectMode: selectMode, selectedId: selectedId),
    );
  }
}

class _AddressesView extends StatelessWidget {
  final bool selectMode;
  final int? selectedId;

  const _AddressesView({required this.selectMode, this.selectedId});

  static const _maxAddresses = 20;

  Future<void> _openForm(BuildContext context, [StoreAddress? edit]) async {
    final saved = await context.push<StoreAddress>(
      AppRoutes.storeAddressForm,
      extra: edit,
    );
    if (saved == null || !context.mounted) return;
    // A freshly added address in select mode is the one they want.
    if (selectMode && edit == null) {
      context.pop(saved);
      return;
    }
    context.read<StoreAddressesCubit>().load(silent: true);
  }

  Future<void> _menu(
    BuildContext context,
    StoreAddress a,
    String action,
  ) async {
    final cubit = context.read<StoreAddressesCubit>();
    switch (action) {
      case 'edit':
        await _openForm(context, a);
      case 'default':
        final error = await cubit.makeDefault(a.id);
        if (error != null && context.mounted) {
          CustomSnackbar.error(context, title: 'Not updated', message: error);
        }
      case 'delete':
        final ok = await showStoreConfirm(
          context,
          title: 'Delete this address?',
          message: '${a.fullName}, ${a.cityLine}',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        final error = await cubit.delete(a.id);
        if (error != null && context.mounted) {
          CustomSnackbar.error(context, title: 'Not deleted', message: error);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: CustomAppBar(title: selectMode ? 'Deliver to' : 'My addresses'),
      body: BlocBuilder<StoreAddressesCubit, StoreAddressesState>(
        builder: (context, state) {
          final cubit = context.read<StoreAddressesCubit>();
          if (state.loading && !state.loaded) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StoreSkeletonBox(height: 120, radius: 16),
                ),
              ),
            );
          }
          if (state.error != null && state.items.isEmpty) {
            return StoreErrorView(message: state.error!, onRetry: cubit.load);
          }
          if (state.items.isEmpty) {
            return StoreEmptyState(
              icon: Icons.add_location_alt_outlined,
              title: 'No saved addresses',
              message: 'Add where you’d like your orders delivered.',
              actionLabel: 'Add address',
              onAction: () => _openForm(context),
            );
          }
          final canAdd = state.items.length < _maxAddresses;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => cubit.load(silent: true),
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                if (canAdd)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _AddTile(onTap: () => _openForm(context)),
                  ),
                for (final a in state.items)
                  _AddressTile(
                    address: a,
                    selectMode: selectMode,
                    selected: a.id == selectedId,
                    busy: state.busyId == a.id,
                    onTap: selectMode ? () => context.pop(a) : null,
                    onAction: (action) => _menu(context, a, action),
                  ),
                if (!canAdd)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'You can keep up to $_maxAddresses addresses. Delete '
                      'one to add another.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTextSmallMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Add a new address',
                style: AppTypography.bodyTextBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final StoreAddress address;
  final bool selectMode;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;
  final ValueChanged<String> onAction;

  const _AddressTile({
    required this.address,
    required this.selectMode,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: AppDecorations.card(
        borderColor: selected ? AppColors.primary.withValues(alpha: 0.7) : null,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 1),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.primary : AppColors.grey300,
                    ),
                  ),
                Expanded(child: StoreAddressSummary(address: address)),
                busy
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.grey400,
                        ),
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        ),
                        onSelected: onAction,
                        itemBuilder: (_) => [
                          _item('edit', Icons.edit_outlined, 'Edit'),
                          if (!address.isDefault)
                            _item(
                              'default',
                              Icons.star_outline_rounded,
                              'Make default',
                            ),
                          _item(
                            'delete',
                            Icons.delete_outline_rounded,
                            'Delete',
                            color: AppColors.error,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 19, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.bodyTextSemiBold.copyWith(color: color),
        ),
      ],
    ),
  );
}
