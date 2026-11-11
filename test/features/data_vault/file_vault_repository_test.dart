import 'dart:io';
import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/data/file_vault_repository.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/bex_codec.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/excel_question_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  late Directory tempDir;
  late BexCodec codec;
  late Uint8List bundledBytes;
  late FileVaultRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cc_dau_thau_vault_test_');
    codec = BexCodec();
    bundledBytes = await codec.encode(
      buildSampleQuestionBank(bankVersion: 'bundled-2026.1'),
    );
    repository = FileVaultRepository(
      supportDirectoryProvider: () async => tempDir,
      bundledAssetLoader: () async => bundledBytes,
      codec: codec,
      excelParser: const ExcelQuestionParser(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileVaultRepository', () {
    test('falls back to bundled asset when active override does not exist', () async {
      final result = await repository.loadActiveBank();

      expect(result, isA<VaultSuccess<QuestionBank>>());
      final bank = (result as VaultSuccess<QuestionBank>).data;
      expect(bank.sourceType, BankSourceType.bundled);
      expect(bank.bankVersion, 'bundled-2026.1');
      expect(bank.questions.length, 430);
    });

    test('imports valid Excel atomically, persists encrypted vault, and resets cleanly', () async {
      final excelBytes = buildSampleExcelBytes(includeExtendedColumns: true);

      final importResult = await repository.importFromBytes(
        excelBytes,
        type: ImportFileType.excel,
      );
      expect(importResult, isA<VaultSuccess<ImportSummary>>());
      final summary = (importResult as VaultSuccess<ImportSummary>).data;
      expect(summary.totalQuestions, 430);
      expect(summary.topicCount, 13);
      expect(summary.sourceType, BankSourceType.importedExcel);

      final reloadResult = await repository.loadActiveBank();
      expect(reloadResult, isA<VaultSuccess<QuestionBank>>());
      final reloaded = (reloadResult as VaultSuccess<QuestionBank>).data;
      expect(reloaded.sourceType, BankSourceType.importedExcel);
      expect(reloaded.questions.first.code, 'Q_001');

      final resetResult = await repository.resetToBundledBank();
      expect(resetResult, isA<VaultSuccess<QuestionBank>>());
      final resetBank = (resetResult as VaultSuccess<QuestionBank>).data;
      expect(resetBank.sourceType, BankSourceType.bundled);
      expect(resetBank.bankVersion, 'bundled-2026.1');
    });

    test('imports valid .bex and preserves existing active vault on failed import', () async {
      final newBex = await codec.encode(
        buildSampleQuestionBank(bankVersion: 'update-2026.2'),
      );
      final okImport = await repository.importFromBytes(
        newBex,
        type: ImportFileType.bex,
      );
      expect(okImport, isA<VaultSuccess<ImportSummary>>());

      // Attempt failed Excel import (corrupted bytes) and failed BEX import
      final badExcel = Uint8List.fromList([1, 2, 3, 4, 5]);
      final errExcel = await repository.importFromBytes(
        badExcel,
        type: ImportFileType.excel,
      );
      expect(errExcel, isA<VaultError<ImportSummary>>());

      final badBex = Uint8List.fromList(newBex)..[19] ^= 0xFF;
      final errBex = await repository.importFromBytes(
        badBex,
        type: ImportFileType.bex,
      );
      expect(errBex, isA<VaultError<ImportSummary>>());

      // Previous valid active vault must remain completely intact
      final stillValid = await repository.loadActiveBank();
      expect(stillValid, isA<VaultSuccess<QuestionBank>>());
      expect(
        (stillValid as VaultSuccess<QuestionBank>).data.bankVersion,
        'update-2026.2',
      );
    });
  });
}

