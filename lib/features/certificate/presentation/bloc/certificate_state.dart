part of 'certificate_cubit.dart';

@freezed
class CertificateState with _$CertificateState {
  const factory CertificateState.initial() = _Initial;
  const factory CertificateState.loading() = _Loading;
  const factory CertificateState.loaded(List<CompletedCourse> courses) =
      _Loaded;
  const factory CertificateState.error(String message) = _Error;
}
