import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';

/// Files a request to delete the signed-in learner's account.
///
/// Exists because App Store Review Guideline 5.1.1(v) requires an app that
/// creates accounts to offer deletion from within the app itself — a link
/// out to a web form is explicitly not enough. Shipped on every platform
/// rather than gated to iOS: the same obligation exists under Google
/// Play's data-deletion policy, and one deletion path is easier to keep
/// correct than two.
///
/// **This is a request, not a deletion.** The backend records a row for
/// back-office processing; the account and its content still exist when
/// this returns. Anything user-facing must say so rather than implying
/// the data is already gone.
///
/// **Deliberately does not touch local session state.** The caller wipes
/// the token, the queued completions and the cached profile *after* this
/// resolves — that teardown has to happen whether or not the call
/// succeeded, and doing it here would leave a failed request with no
/// token to retry on. It is also not optional: the server revokes only
/// the refresh-token family, so the access token the app already holds
/// stays valid for up to seven days.
class DeleteAccountUseCase {
  final ProfileRepository repository;

  DeleteAccountUseCase(this.repository);

  /// Longest reason the API is asked to store. No server-side cap is
  /// enforced, but the value lands in a database column, so it is trimmed
  /// here rather than discovered as a 500.
  static const int maxReasonLength = 500;

  /// [reason] is mandatory — a blank one is rejected by the API with a
  /// 400. Checked here too so an empty field costs no round trip and the
  /// learner gets a message written for them rather than the server's.
  Future<Either<Failure, Unit>> call({required String reason}) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Left(
          Failure.unknown(message: 'Please tell us why you are leaving.'),
        ),
      );
    }
    return repository.deleteAccount(
      reason: trimmed.length > maxReasonLength
          ? trimmed.substring(0, maxReasonLength)
          : trimmed,
    );
  }
}
