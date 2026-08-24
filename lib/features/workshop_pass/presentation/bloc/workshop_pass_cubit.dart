import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/get_workshop_pass_usecase.dart';

part 'workshop_pass_state.dart';
part 'workshop_pass_cubit.freezed.dart';

/// Drives the workshop pass screen.
///
/// **Cache first, then the network.** The pass exists to be opened in a
/// queue at a door, so the saved copy goes on screen the moment there is
/// one and the fetch runs behind it. That is safe because the pass
/// number and the QR are frozen server-side at first issue: a cached
/// pass and a fresh one are the same ticket, and only the artwork can
/// have changed.
///
/// The refusals are branched on status rather than on wording, and only
/// one of them is an error:
///
///  * **402** is not a failure at all — it is the state *before* buying,
///    and belongs in the purchase flow. If the local purchase state said
///    otherwise, the server is right and the app is wrong.
///  * **409** means the organiser has something to fix (a free or
///    cancelled workshop, a withdrawn design) or that this is not a
///    workshop at all. Information, not the attendee's mistake.
///  * everything else is a genuine error, with a retry.
class WorkshopPassCubit extends SafeCubit<WorkshopPassState> {
  final GetWorkshopPassUseCase getWorkshopPassUseCase;

  WorkshopPassCubit({required this.getWorkshopPassUseCase})
    : super(const WorkshopPassState.initial());

  /// The pass currently on screen, if any — so the save button can act
  /// without the page reaching back into the state itself.
  WorkshopPass? get pass =>
      state.maybeWhen(loaded: (pass, _) => pass, orElse: () => null);

  Future<void> load(String slug) async {
    final cached = await getWorkshopPassUseCase.cached(slug);
    if (isClosed) return;

    if (cached != null) {
      // Straight on screen. Nothing about a cached pass is provisional:
      // it scans exactly as a freshly fetched one does.
      emit(WorkshopPassState.loaded(cached, true));
    } else {
      emit(const WorkshopPassState.loading());
    }

    final result = await getWorkshopPassUseCase(slug);
    if (isClosed) return;

    result.fold(
      (failure) {
        // A refresh that fails while a cached pass is showing changes
        // nothing: the ticket in front of them is still the ticket. This
        // is the whole point of caching it — the door is exactly where
        // the network is worst.
        if (cached != null) return;
        emit(_refusalFor(failure));
      },
      (pass) => emit(WorkshopPassState.loaded(pass, false)),
    );
  }

  /// Re-runs the fetch without dropping what is on screen. Used by the
  /// pull-to-refresh and after a check-in, where the only thing that can
  /// have changed is `isCheckedIn` and the artwork.
  Future<void> silentRefresh(String slug) async {
    final result = await getWorkshopPassUseCase(slug);
    if (isClosed) return;
    result.fold(
      (failure) {
        if (pass != null) return;
        emit(_refusalFor(failure));
      },
      (fresh) => emit(WorkshopPassState.loaded(fresh, false)),
    );
  }

  WorkshopPassState _refusalFor(Failure failure) {
    final status = failure.maybeWhen(
      server: (_, statusCode) => statusCode,
      orElse: () => null,
    );

    switch (status) {
      case 402:
        return WorkshopPassState.needsPurchase(failure.message);
      case 409:
      case 404:
        return WorkshopPassState.unavailable(failure.message);
      default:
        return WorkshopPassState.error(failure.message);
    }
  }
}
