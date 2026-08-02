class MortError implements Exception {
  const MortError(this.message);

  final String message;

  @override
  String toString() => message;
}

class MortCodedError extends MortError {
  const MortCodedError(this.code, super.message);

  final String code;
}

class MortFieldCodedError extends MortCodedError {
  const MortFieldCodedError(super.code, super.message, {required this.field});

  final String field;
}

class MortBackendNotConfiguredError extends MortError {
  const MortBackendNotConfiguredError()
    : super(
        'MORT cannot connect securely right now. Close and reopen the app, then try again.',
      );
}
