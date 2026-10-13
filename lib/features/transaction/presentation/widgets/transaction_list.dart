import 'dart:convert';
import 'dart:io';

import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/transaction/data/models/receipt_model.dart';
import 'package:nexora/features/transaction/data/models/transaction_model.dart';
import 'package:nexora/features/transaction/domain/usecases/download_receipt_usecase.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';
import 'package:nexora/features/transaction/presentation/widgets/empty_view.dart';
import 'package:nexora/features/transaction/presentation/widgets/transaction_history_card.dart';
import 'package:dartz/dartz.dart' show Either;
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
            onTap: transaction.hasDocument
                ? () => openTransactionDocument(context, transaction)
                : null,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 20),
      ),
    );
  }
}

/// Opens a transaction's document: the course receipt for a course
/// payment, the invoice (or, before it ships, the payment receipt) for a
/// store order.
///
/// Never sends a store order to the course receipt endpoint: an order's
/// numbers can collide with an unrelated course transaction id.
Future<void> openTransactionDocument(
  BuildContext context,
  TransactionModel transaction,
) {
  if (transaction.isProduct) {
    return openStoreInvoice(context, transaction.orderNo!);
  }
  return _openDocument(
    context,
    () => sl<DownloadReceiptUseCase>()(transaction.transactionId!),
  );
}

/// A store order's invoice / payment receipt. Also used by the store's
/// order detail page, so both open the same document the same way.
Future<void> openStoreInvoice(BuildContext context, String orderNo) =>
    _openDocument(context, () => sl<DownloadStoreInvoiceUseCase>()(orderNo));

/// Fetches the document HTML (needs the JWT, so it's fetched in-app —
/// a browser tab can't carry the auth header) and hands it to the
/// device's external browser.
Future<void> _openDocument(
  BuildContext context,
  Future<Either<Failure, ReceiptModel>> Function() fetch,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );

  final result = await fetch();

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
    Future.delayed(const Duration(minutes: 2), () => server.close(force: true));

    final uri = Uri.parse('http://127.0.0.1:${server.port}/receipt.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      CustomSnackbar.error(
        context,
        title: 'Cannot Open',
        message: 'No browser app available to open the document.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      CustomSnackbar.error(
        context,
        title: 'Cannot Open',
        message: 'Could not open the document: $e',
      );
    }
  }
}
