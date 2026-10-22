import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/bundles/data/models/bundle_model.dart';
import 'package:nexora/features/bundles/domain/usecases/bundle_usecases.dart';

part 'bundle_detail_state.dart';
part 'bundle_detail_cubit.freezed.dart';

/// B2 — the bundle page.
class BundleDetailCubit extends SafeCubit<BundleDetailState> {
  final GetBundleDetailUseCase getBundleDetailUseCase;

  BundleDetailCubit({required this.getBundleDetailUseCase})
    : super(const BundleDetailState.loading());

  /// [silent] keeps the current page on screen and, on failure, leaves
  /// it there — used after a purchase or a refused order, where the
  /// page is already showing something true enough.
  Future<void> load(int bundleId, {bool silent = false}) async {
    final hasPage = state.maybeWhen(loaded: (_) => true, orElse: () => false);
    if (!silent || !hasPage) emit(const BundleDetailState.loading());

    final result = await getBundleDetailUseCase(bundleId);
    result.fold((failure) {
      if (silent && hasPage) return;
      final notFound = failure.maybeWhen(
        server: (_, statusCode) => statusCode == 404,
        orElse: () => false,
      );
      emit(
        BundleDetailState.error(
          notFound ? 'This bundle is no longer available.' : failure.message,
          notFound,
        ),
      );
    }, (detail) => emit(BundleDetailState.loaded(detail)));
  }
}
