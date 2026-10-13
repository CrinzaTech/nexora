import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/store/data/models/store_order_model.dart';
import 'package:nexora/features/store/domain/usecases/store_order_usecases.dart';
import 'package:nexora/features/store/presentation/store_failure.dart';
import 'package:dartz/dartz.dart' show Either;

part 'store_order_detail_state.dart';
part 'store_order_detail_cubit.freezed.dart';

/// O2 plus the three things a learner can do to an order: cancel (O3),
/// confirm delivery (O4) and rate an item (O5).
///
/// Which of those is offered is the server's call (`canCancel`,
/// `canConfirmReceived`, `canReview`); after each one the order is
/// re-read so the buttons follow the new state.
class StoreOrderDetailCubit extends SafeCubit<StoreOrderDetailState> {
  final GetStoreOrderUseCase getOrderUseCase;
  final CancelStoreOrderUseCase cancelOrderUseCase;
  final ConfirmStoreOrderReceivedUseCase confirmReceivedUseCase;
  final ReviewStoreItemUseCase reviewItemUseCase;
  final String orderNo;

  StoreOrderDetailCubit({
    required this.getOrderUseCase,
    required this.cancelOrderUseCase,
    required this.confirmReceivedUseCase,
    required this.reviewItemUseCase,
    required this.orderNo,
  }) : super(const StoreOrderDetailState());

  Future<void> load({bool silent = false}) async {
    if (!silent || state.order == null) {
      emit(state.copyWith(loading: true, error: null));
    }
    final result = await getOrderUseCase(orderNo);
    result.fold(
      (failure) => emit(
        state.copyWith(
          loading: false,
          error: silent && state.order != null ? null : storeErrorText(failure),
        ),
      ),
      (order) =>
          emit(state.copyWith(loading: false, order: order, error: null)),
    );
  }

  /// Each returns `(ok, message)`: the server's message either way.
  Future<(bool, String)> cancel({String? reason}) =>
      _act(() => cancelOrderUseCase(orderNo, reason: reason));

  Future<(bool, String)> confirmReceived() =>
      _act(() => confirmReceivedUseCase(orderNo));

  Future<(bool, String)> review(
    int itemId, {
    required int rating,
    String? comment,
  }) => _act(
    () => reviewItemUseCase(orderNo, itemId, rating: rating, comment: comment),
  );

  Future<(bool, String)> _act(
    Future<Either<Failure, String>> Function() send,
  ) async {
    emit(state.copyWith(acting: true));
    final result = await send();
    final outcome = result.fold(
      (failure) => (false, storeErrorText(failure)),
      (message) => (true, message),
    );
    if (outcome.$1) await load(silent: true);
    emit(state.copyWith(acting: false));
    return outcome;
  }
}
