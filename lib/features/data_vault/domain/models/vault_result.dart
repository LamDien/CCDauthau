/// Typed result wrapper returned across the `data-vault` module boundary.
sealed class VaultResult<T> {
  const VaultResult();
}

final class VaultSuccess<T> extends VaultResult<T> {
  const VaultSuccess(this.data);
  final T data;
}

final class VaultError<T> extends VaultResult<T> {
  const VaultError(this.failure);
  final VaultFailure failure;
}

/// Single row-level validation error produced when parsing Excel files.
final class ExcelRowError {
  const ExcelRowError({
    required this.rowNumber,
    required this.columnName,
    required this.message,
  });

  final int rowNumber;
  final String columnName;
  final String message;

  @override
  String toString() => 'Dòng $rowNumber ($columnName): $message';
}

/// Typed failures for `data-vault` operations.
sealed class VaultFailure {
  const VaultFailure(this.code, this.message);

  final String code;
  final String message;
}

final class ExcelValidationFailure extends VaultFailure {
  ExcelValidationFailure(List<ExcelRowError> rowErrors, {String? message})
      : rowErrors = List<ExcelRowError>.unmodifiable(rowErrors),
        super(
          'EXCEL_VALIDATION_ERROR',
          message ?? 'File Excel có ${rowErrors.length} lỗi dữ liệu cần chỉnh sửa.',
        );

  final List<ExcelRowError> rowErrors;
}

final class InsufficientBankFailure extends VaultFailure {
  const InsufficientBankFailure(String message)
      : super('INSUFFICIENT_TOPICS_OR_QUESTIONS', message);
}

final class CorruptedVaultFailure extends VaultFailure {
  const CorruptedVaultFailure(String message)
      : super('CORRUPTED_VAULT', message);
}

final class StorageFailure extends VaultFailure {
  const StorageFailure(String message) : super('STORAGE_ERROR', message);
}

