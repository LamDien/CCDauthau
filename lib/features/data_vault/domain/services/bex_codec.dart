import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cryptography/cryptography.dart';

/// Encodes and decodes `.bex` encrypted question bank files (`BEX1` format:
/// 4B magic "BEX1" + 2B BE version + 12B nonce + AES-256-GCM(Gzip(JSON)) + 16B MAC).
final class BexCodec {
  BexCodec({
    this.requiredTopicCount = 13,
    this.minimumQuestionCount = 70,
  }) : _cipher = AesGcm.with256bits();

  final int requiredTopicCount;
  final int minimumQuestionCount;
  final AesGcm _cipher;

  static const List<int> _magic = [0x42, 0x45, 0x58, 0x31]; // "BEX1"
  static const int _version = 1;
  static const int _headerLength = 6;

  // Key material split into masked shards and assembled at runtime
  // so no plain secret string exists in compiled binary literals.
  static const List<int> _shardA = [
    0x6A, 0x1F, 0x94, 0x32, 0xC8, 0x51, 0x0E, 0x77,
    0xB3, 0x29, 0xD4, 0x61, 0x8F, 0x42, 0x19, 0xEA,
  ];
  static const List<int> _maskA = [
    0x39, 0x7A, 0xC1, 0x5E, 0xA2, 0x18, 0x4B, 0x93,
    0xE6, 0x6D, 0x80, 0x34, 0xDB, 0x17, 0x5C, 0xAF,
  ];
  static const List<int> _shardB = [
    0x4E, 0xA3, 0x12, 0x9D, 0x76, 0xC0, 0x58, 0x2F,
    0x81, 0xB4, 0x3A, 0xE5, 0x07, 0x6C, 0xD2, 0x98,
  ];
  static const List<int> _maskB = [
    0x1C, 0xF5, 0x47, 0xB8, 0x23, 0x9E, 0x6A, 0xD1,
    0x50, 0x89, 0x7E, 0x02, 0xA4, 0x3D, 0x95, 0x6B,
  ];

  /// Compresses and encrypts [bank] into `.bex` binary format.
  Future<Uint8List> encode(QuestionBank bank) async {
    final jsonBytes = utf8.encode(jsonEncode(bank.toJson()));
    final compressed = gzip.encode(jsonBytes);
    final header = _buildHeader();
    final secretKey = await _deriveSecretKey();

    final box = await _cipher.encrypt(
      compressed,
      secretKey: secretKey,
      aad: header,
    );

    final concatenated = box.concatenation();
    final output = Uint8List(header.length + concatenated.length);
    output.setRange(0, header.length, header);
    output.setRange(header.length, output.length, concatenated);
    return output;
  }

  /// Authenticates, decrypts, decompresses, and validates `.bex` [bytes].
  Future<VaultResult<QuestionBank>> decode(
    Uint8List bytes, {
    BankSourceType sourceType = BankSourceType.importedBex,
  }) async {
    final minLength =
        _headerLength + _cipher.nonceLength + _cipher.macAlgorithm.macLength + 1;
    if (bytes.length < minLength) {
      return const VaultError(
        CorruptedVaultFailure('Gói dữ liệu .bex không hợp lệ hoặc bị cắt cụt.'),
      );
    }

    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        return const VaultError(
          CorruptedVaultFailure('Định dạng tệp không phải gói .bex hợp lệ.'),
        );
      }
    }

    final fileVersion = (bytes[4] << 8) | bytes[5];
    if (fileVersion != _version) {
      return VaultError(
        CorruptedVaultFailure('Phiên bản tệp .bex ($fileVersion) không được hỗ trợ.'),
      );
    }

    try {
      final header = Uint8List.sublistView(bytes, 0, _headerLength);
      final payload = Uint8List.sublistView(bytes, _headerLength);
      final box = SecretBox.fromConcatenation(
        payload,
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
        copy: false,
      );
      final secretKey = await _deriveSecretKey();
      final compressed = await _cipher.decrypt(
        box,
        secretKey: secretKey,
        aad: header,
      );
      final jsonBytes = gzip.decode(compressed);
      final decodedMap = Map<String, Object?>.from(
        jsonDecode(utf8.decode(jsonBytes)) as Map,
      );
      final bank = QuestionBank.fromJson(decodedMap, sourceType: sourceType);

      if (bank.topics.length != requiredTopicCount ||
          bank.questions.length < minimumQuestionCount) {
        return VaultError(
          InsufficientBankFailure(
            'Gói dữ liệu phải có đủ $requiredTopicCount chuyên đề và tối thiểu '
            '$minimumQuestionCount câu hỏi.',
          ),
        );
      }
      return VaultSuccess(bank);
    } on VaultFailure catch (e) {
      return VaultError(e);
    } catch (_) {
      return const VaultError(
        CorruptedVaultFailure(
          'Không thể giải mã gói .bex (tệp bị chỉnh sửa hoặc hư hỏng).',
        ),
      );
    }
  }

  Uint8List _buildHeader() {
    return Uint8List.fromList([
      ..._magic,
      (_version >> 8) & 0xFF,
      _version & 0xFF,
    ]);
  }

  Future<SecretKey> _deriveSecretKey() async {
    final keyBytes = Uint8List(32);
    for (var i = 0; i < 16; i++) {
      final a = _shardA[i] ^ _maskA[i];
      keyBytes[i] = ((a << 3) | (a >> 5)) & 0xFF;
      final b = _shardB[i] ^ _maskB[i];
      keyBytes[16 + i] = ((b >> 2) | (b << 6)) & 0xFF;
    }
    final digest = await Sha256().hash(keyBytes);
    return SecretKey(digest.bytes);
  }
}

