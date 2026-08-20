import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/services/org_code_service.dart';
import 'package:nexora/features/auth/domain/usecases/validate_org_code_usecase.dart';

// ─── States ─────────────────────────────────────────────────────────────────

abstract class OrgCodeState {
  const OrgCodeState();
}

/// Waiting for user input.
class OrgCodeInitial extends OrgCodeState {
  const OrgCodeInitial();
}

/// API call in-flight.
class OrgCodeLoading extends OrgCodeState {
  const OrgCodeLoading();
}

/// Code accepted by the backend — [orgCode] is the validated value.
class OrgCodeValid extends OrgCodeState {
  final String orgCode;
  const OrgCodeValid(this.orgCode);
}

/// API returned an error or `isValid: false`.
class OrgCodeError extends OrgCodeState {
  final String message;
  const OrgCodeError(this.message);
}

// ─── Cubit ──────────────────────────────────────────────────────────────────

class OrgCodeCubit extends SafeCubit<OrgCodeState> {
  final ValidateOrgCodeUseCase _validateOrgCodeUseCase;

  OrgCodeCubit(this._validateOrgCodeUseCase) : super(const OrgCodeInitial());

  /// Call the backend to validate [orgCode].
  ///
  /// On success the code is stored in [OrgCodeService] so all downstream
  /// OTP use cases pick it up automatically, and [OrgCodeValid] is emitted.
  /// On failure [OrgCodeError] is emitted with the server message.
  Future<void> validate(String orgCode) async {
    emit(const OrgCodeLoading());

    final result = await _validateOrgCodeUseCase(orgCode: orgCode.trim());

    result.fold(
      (failure) => emit(OrgCodeError(failure.message)),
      (_) {
        OrgCodeService.instance.setOrgCode(orgCode.trim());
        emit(OrgCodeValid(orgCode.trim()));
      },
    );
  }

  /// Reset to initial so the page can be reused without stale state.
  void reset() => emit(const OrgCodeInitial());
}
