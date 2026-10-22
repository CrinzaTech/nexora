import 'package:dartz/dartz.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';

/// One fetch feeding one supplementary rail — B3, X1 or X2.
///
/// The state is just the list: `null` until it lands, and an empty list
/// both for "nothing linked" and for a failed fetch. Every one of these
/// rails hides itself in either case, so there is nothing more to model.
class RelatedItemsCubit<T> extends SafeCubit<List<T>?> {
  final Future<Either<Failure, List<T>>> Function() _fetch;

  RelatedItemsCubit(this._fetch) : super(null);

  Future<void> load() async {
    final result = await _fetch();
    emit(result.fold((_) => const [], (items) => items));
  }
}
