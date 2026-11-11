import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/repositories/vault_repository.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/bex_codec.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/excel_question_parser.dart';
import 'package:path/path.dart' as p;

/// File-backed encrypted question vault supporting atomic updates and bundled fallback.
final class FileVaultRepository implements VaultRepository {
  FileVaultRepository({
    required this._supportDirectoryProvider,
    required this._bundledAssetLoader,
    BexCodec? codec,
    ExcelQuestionParser? excelParser,
  })  : _codec = codec ?? BexCodec(),
        _excelParser = excelParser ?? const ExcelQuestionParser();

  final Future<Directory> Function() _supportDirectoryProvider;
  final Future<Uint8List> Function() _bundledAssetLoader;
  final BexCodec _codec;
  final ExcelQuestionParser _excelParser;

  static const String _vaultFolderName = 'vault';
  static const String _activeFileName = 'active_bank.bex';
  static const String _metaFileName = 'vault_meta.json';

  @override
  Future<VaultResult<QuestionBank>> loadActiveBank() async {
    try {
      final vaultDir = await _vaultDirectory();
      final activeFile = File(p.join(vaultDir.path, _activeFileName));
      if (await activeFile.exists()) {
        final meta = await _readMetadata(vaultDir);
        final bytes = await activeFile.readAsBytes();
        final decoded = await _codec.decode(
          bytes,
          sourceType: meta.$1 ?? BankSourceType.importedBex,
        );
        if (decoded is VaultSuccess<QuestionBank>) {
          final bank = meta.$2 != null
              ? decoded.data.copyWith(importedAt: meta.$2)
              : decoded.data;
          return VaultSuccess(bank);
        }
        return decoded;
      }

      final bundledBytes = await _bundledAssetLoader();
      return await _codec.decode(
        bundledBytes,
        sourceType: BankSourceType.bundled,
      );
    } catch (e) {
      return VaultError(
        StorageFailure('Không thể nạp kho câu hỏi cục bộ ($e).'),
      );
    }
  }

  @override
  Future<VaultResult<ImportSummary>> importFromBytes(
    Uint8List bytes, {
    required ImportFileType type,
  }) async {
    final now = DateTime.now().toUtc();
    final QuestionBank validatedBank;
    final Uint8List bexBytes;

    switch (type) {
      case ImportFileType.excel:
        final version = _formatVersion(now);
        final parsed = _excelParser.parse(
          bytes,
          bankVersion: version,
          sourceType: BankSourceType.importedExcel,
          importedAt: now,
        );
        switch (parsed) {
          case VaultError<QuestionBank>(:final failure):
            return VaultError(failure);
          case VaultSuccess<QuestionBank>(:final data):
            validatedBank = data;
            bexBytes = await _codec.encode(validatedBank);
        }
      case ImportFileType.bex:
        final decoded = await _codec.decode(
          bytes,
          sourceType: BankSourceType.importedBex,
        );
        switch (decoded) {
          case VaultError<QuestionBank>(:final failure):
            return VaultError(failure);
          case VaultSuccess<QuestionBank>(:final data):
            validatedBank = data.copyWith(importedAt: now);
            bexBytes = bytes;
        }
    }

    // Verify round-trip before swapping into active storage.
    final verifyResult = await _codec.decode(
      bexBytes,
      sourceType: validatedBank.sourceType,
    );
    if (verifyResult is VaultError<QuestionBank>) {
      return VaultError(verifyResult.failure);
    }

    try {
      final vaultDir = await _vaultDirectory();
      final activePath = p.join(vaultDir.path, _activeFileName);
      final tempBex = File('$activePath.tmp');
      await tempBex.writeAsBytes(bexBytes, flush: true);

      // Re-verify written temporary file on disk before atomic rename.
      final diskVerify = await _codec.decode(
        await tempBex.readAsBytes(),
        sourceType: validatedBank.sourceType,
      );
      if (diskVerify is VaultError<QuestionBank>) {
        if (await tempBex.exists()) await tempBex.delete();
        return VaultError(diskVerify.failure);
      }

      await tempBex.rename(activePath);
      await _writeMetadata(vaultDir, validatedBank.sourceType, now);
      return VaultSuccess(validatedBank.toSummary());
    } catch (e) {
      return VaultError(
        StorageFailure('Không thể lưu tệp cập nhật câu hỏi ($e).'),
      );
    }
  }

  @override
  Future<VaultResult<QuestionBank>> resetToBundledBank() async {
    try {
      final vaultDir = await _vaultDirectory();
      final activeFile = File(p.join(vaultDir.path, _activeFileName));
      final metaFile = File(p.join(vaultDir.path, _metaFileName));
      if (await activeFile.exists()) {
        await activeFile.delete();
      }
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
      return await loadActiveBank();
    } catch (e) {
      return VaultError(
        StorageFailure('Không thể khôi phục bộ câu hỏi mặc định ($e).'),
      );
    }
  }

  Future<Directory> _vaultDirectory() async {
    final root = await _supportDirectoryProvider();
    final dir = Directory(p.join(root.path, _vaultFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<(BankSourceType?, DateTime?)> _readMetadata(Directory vaultDir) async {
    final metaFile = File(p.join(vaultDir.path, _metaFileName));
    if (!await metaFile.exists()) return (null, null);
    try {
      final map = Map<String, Object?>.from(
        jsonDecode(await metaFile.readAsString()) as Map,
      );
      final sourceName = map['sourceType'] as String?;
      final importedAtRaw = map['importedAtIso'] as String?;
      final sourceType = BankSourceType.values
          .where((e) => e.name == sourceName)
          .firstOrNull;
      final importedAt =
          importedAtRaw != null ? DateTime.tryParse(importedAtRaw) : null;
      return (sourceType, importedAt);
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _writeMetadata(
    Directory vaultDir,
    BankSourceType sourceType,
    DateTime importedAt,
  ) async {
    final metaPath = p.join(vaultDir.path, _metaFileName);
    final tempMeta = File('$metaPath.tmp');
    await tempMeta.writeAsString(
      jsonEncode({
        'sourceType': sourceType.name,
        'importedAtIso': importedAt.toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await tempMeta.rename(metaPath);
  }

  String _formatVersion(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y.$m.$d-$hh$mm';
  }
}
