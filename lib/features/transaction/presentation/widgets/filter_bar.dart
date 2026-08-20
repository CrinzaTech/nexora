import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/transaction/domain/enums/transaction_filter.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';
import 'package:nexora/features/transaction/presentation/widgets/date_pill.dart';
import 'package:nexora/features/transaction/presentation/widgets/filter_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal filter bar — a [DatePill] popup followed by one
/// [FilterPill] per [TransactionPaymentStatus]. Both pill kinds feed
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
