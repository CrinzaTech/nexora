import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/transaction/domain/enums/transaction_filter.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';
import 'package:nexora/features/transaction/presentation/widgets/date_pill.dart';
import 'package:nexora/features/transaction/presentation/widgets/filter_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal filter bar: one [FilterPill] per [TransactionKindFilter]
/// (Everything / Courses / Products), a divider, a [DatePill] popup, then
/// one [FilterPill] per [TransactionPaymentStatus]. All of them feed
/// the same [TransactionHistoryCubit] so the API URL stays in one
/// place and selection state highlights consistently.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionHistoryCubit, TransactionHistoryState>(
      builder: (context, _) {
        final cubit = context.read<TransactionHistoryCubit>();
        return SizedBox.fromSize(
          size: Size.fromHeight(Screen.getVerticalSize(45)),
          child: ListView(
            padding: Screen.getPadding(horizontal: 15, vertical: 4),
            scrollDirection: Axis.horizontal,
            children: [
              for (final kind in TransactionKindFilter.values) ...[
                FilterPill(
                  label: kind.label,
                  selected: cubit.kind == kind,
                  onTap: () => cubit.setKind(kind),
                ),
                SizedBox(width: Screen.getHorizontalSize(10)),
              ],
              // Separates "what" from "when / how it went".
              Center(
                child: Container(
                  width: 1,
                  height: Screen.getVerticalSize(22),
                  color: AppColors.dividerLight,
                ),
              ),
              SizedBox(width: Screen.getHorizontalSize(10)),
              DatePill(value: cubit.timeFilter, onChanged: cubit.setTimeFilter),
              SizedBox(width: Screen.getHorizontalSize(10)),
              for (final s in TransactionPaymentStatus.values) ...[
                FilterPill(
                  label: s.label,
                  selected: cubit.paymentStatus == s,
                  onTap: () => cubit.setPaymentStatus(s),
                ),
                SizedBox(width: Screen.getHorizontalSize(10)),
              ],
            ],
          ),
        );
      },
    );
  }
}
