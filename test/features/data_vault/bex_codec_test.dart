import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/bex_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  final codec = BexCodec();

  group('BexCodec', () {
    test('round-trips 430 Vietnamese questions without exposing plaintext', () async {
      final original = buildSampleQuestionBank(withPointGroups: true);

      final encoded = await codec.encode(original);

      // Verify BEX1 header + version 1
      expect(utf8.decode(encoded.sublist(0, 4)), 'BEX1');
      expect(encoded[4], 0);
      expect(encoded[5], 1);

      // Verify encoded payload is compressed & encrypted (not plain JSON/text)
      final rawLatin = latin1.decode(encoded);
      expect(rawLatin, isNot(contains('Luật Đấu thầu')));
      expect(rawLatin, isNot(contains('"questions"')));

      final decodedResult = await codec.decode(
        encoded,
        sourceType: BankSourceType.importedBex,
      );
      expect(decodedResult, isA<VaultSuccess<QuestionBank>>());
      final decoded = (decodedResult as VaultSuccess<QuestionBank>).data;
      expect(decoded.questions.length, 430);
      expect(decoded.topics.length, 13);
      expect(decoded.questions.first.stem, original.questions.first.stem);
      expect(decoded.questions.first.pointGroupKey, original.questions.first.pointGroupKey);
      expect(decoded.sourceType, BankSourceType.importedBex);
    });

    test('rejects invalid magic bytes, truncated payloads, and tampered bits', () async {
      final bank = buildSampleQuestionBank();
      final encoded = await codec.encode(bank);

      final wrongMagic = Uint8List.fromList(encoded)..[0] = 0x58;
      expect(await codec.decode(wrongMagic), isA<VaultError<QuestionBank>>());

      final truncated = Uint8List.sublistView(encoded, 0, 20);
      expect(await codec.decode(truncated), isA<VaultError<QuestionBank>>());

      final flippedBit = Uint8List.fromList(encoded);
      flippedBit[25] ^= 0x01;
      final tamperResult = await codec.decode(flippedBit);
      expect(tamperResult, isA<VaultError<QuestionBank>>());
      expect(
        (tamperResult as VaultError<QuestionBank>).failure,
        isA<CorruptedVaultFailure>(),
      );
    });

    test('bundled assets/vault/default_bank.bex decrypts cleanly to 430 questions across 13 topics', () async {
      final file = File('assets/vault/default_bank.bex');
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      final result = await codec.decode(bytes, sourceType: BankSourceType.bundled);
      expect(result, isA<VaultSuccess<QuestionBank>>());
      final bank = (result as VaultSuccess<QuestionBank>).data;
      expect(bank.questions.length, 430);
      expect(bank.topics.length, 13);
    });
  });
}
