import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';
import 'package:nexora/features/transaction/presentation/widgets/error_view.dart';
import 'package:nexora/features/transaction/presentation/widgets/filter_bar.dart';
import 'package:nexora/features/transaction/presentation/widgets/transaction_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/custom_appbar_widget.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionHistoryCubit>()..load(),
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Transaction History'),
        body: SafeArea(
          child: Column(
            children: [
              const FilterBar(),
              Expanded(
                child:
                    BlocBuilder<
                      TransactionHistoryCubit,
                      TransactionHistoryState
                    >(
                      builder: (context, state) {
                        return state.maybeWhen(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (message) => ErrorView(
                            message: message,
                            onRetry: () =>
                                context.read<TransactionHistoryCubit>().load(),
                          ),
                          loaded: (list) => TransactionList(list: list),
                          orElse: () =>
                              const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
