import 'package:nexora/core/error/failures.dart';

/// How a Store [Failure] reads to a learner (STORE_API.md §9).
///
/// 400 / 403 / 404 / 409 carry a `message` written to be shown as-is;
/// a 5xx is the server's problem and gets the generic line instead.
String storeErrorText(Failure failure) {
  final status = storeStatusOf(failure);
  if (status != null && status >= 500) {
    return 'Something went wrong. Please try again.';
  }
  final message = failure.message.trim();
  return message.isEmpty ? 'Something went wrong. Please try again.' : message;
}

int? storeStatusOf(Failure failure) =>
    failure is ServerFailure ? failure.statusCode : null;

/// The organisation does not have the Store switched on. The entry point
/// is hidden rather than shown as an error.
bool isStoreOff(Failure failure) {
  if (storeStatusOf(failure) != 403) return false;
  return failure.message.toLowerCase().contains('store is not available');
}
