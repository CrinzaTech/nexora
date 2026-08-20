import 'dart:convert';
import 'dart:io';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/transaction/data/models/transaction_model.dart';
import 'package:nexora/features/transaction/domain/usecases/download_receipt_usecase.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';
import 'package:nexora/features/transaction/presentation/widgets/empty_view.dart';
import 'package:nexora/features/transaction/presentation/widgets/transaction_history_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pull-to-refreshable list of [TransactionHistoryCard]s, falling back
/// to [EmptyView] when the cubit reports a loaded-but-empty list.
class TransactionList extends StatelessWidget {
  final List<TransactionModel> list;

  const TransactionList({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const EmptyView();
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<TransactionHistoryCubit>().silentRefresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: Screen.getPadding(vertical: 20),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final transaction = list[i];
          return TransactionHistoryCard(
            transaction: transaction,
            onTap: transaction.transactionId == null
                ? null
                : () => _openReceipt(context, transaction.transactionId!),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 20),
      ),
    );
  }

  /// Fetches the receipt HTML (needs the JWT, so it's fetched in-app —
  /// a browser tab can't carry the auth header) and hands it to the
  /// device's external browser as a `data:` URI.
  Future<void> _openReceipt(BuildContext context, int transactionId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final result = await sl<DownloadReceiptUseCase>()(transactionId);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await result.fold(
      (failure) async => CustomSnackbar.error(
        context,
        title: 'Cannot Open',
        message: failure.message,
      ),
      (receipt) => _launchInBrowser(context, receipt.html),
    );
  }

  /// Browsers don't register an intent-filter for the `data:` scheme, so
  /// `canLaunchUrl`/`launchUrl` on a `data:` URI silently fails on
  /// Android ("no browser to open"). A real `http://` URL is the only
  /// scheme every browser is guaranteed to handle, so the HTML is served
  /// from a one-shot loopback server instead — `dart:io`'s `HttpServer`,
  /// no extra package needed.
  Future<void> _launchInBrowser(BuildContext context, String html) async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bytes = utf8.encode(html);

      server.first.then((request) async {
        request.response.headers.contentType = ContentType.html;
        request.response.add(bytes);
        await request.response.close();
        await server.close();
      });
      // Safety net in case the browser never requests the page (e.g. the
      // user backs out of the app chooser) — don't leak the socket.
      Future.delayed(
        const Duration(minutes: 2),
        () => server.close(force: true),
      );

      final uri = Uri.parse('http://127.0.0.1:${server.port}/receipt.html');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        CustomSnackbar.error(
          context,
          title: 'Cannot Open',
          message: 'No browser app available to open the receipt.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(
          context,
          title: 'Cannot Open',
          message: 'Could not open the receipt: $e',
        );
      }
    }
  }
}
