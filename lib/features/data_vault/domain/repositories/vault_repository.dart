import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';

/// Contract for loading, updating, and resetting the encrypted question vault.
abstract interface class VaultRepository {
  /// Loads the currently active question bank (`active_bank.bex` or bundled fallback).
  Future<VaultResult<QuestionBank>> loadActiveBank();

  /// Validates and atomically replaces the active bank from `.bex` or `.xlsx` bytes.
  Future<VaultResult<ImportSummary>> importFromBytes(
    Uint8List bytes, {
    required ImportFileType type,
  });

  /// Removes any imported override and reloads the bundled default bank.
  Future<VaultResult<QuestionBank>> resetToBundledBank();
}

