import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/features/store/data/models/store_product_model.dart';
import 'package:nexora/features/store/domain/usecases/store_catalog_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';

part 'store_product_detail_state.dart';
part 'store_product_detail_cubit.freezed.dart';

/// C4 — one product page.
class StoreProductDetailCubit extends SafeCubit<StoreProductDetailState> {
  final GetStoreProductUseCase getProductUseCase;

  StoreProductDetailCubit({required this.getProductUseCase})
    : super(const StoreProductDetailState.loading());

  Future<void> load(String productId, {bool silent = false}) async {
    if (!silent) emit(const StoreProductDetailState.loading());
    final result = await getProductUseCase(productId);
    result.fold((failure) {
      // A silent refresh keeps the page that is already showing.
      if (silent) return;
      emit(
        StoreProductDetailState.error(
          storeErrorText(failure),
          notFound: storeStatusOf(failure) == 404,
        ),
      );
    }, (product) => emit(StoreProductDetailState.loaded(product)));
  }
}
