import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/excel_question_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  const parser = ExcelQuestionParser();

  group('ExcelQuestionParser', () {
    test('parses valid 9-column Vietnamese Excel with 430 questions and 13 topics', () {
      final bytes = buildSampleExcelBytes(includeTrailingBlankRows: true);

      final result = parser.parse(
        bytes,
        bankVersion: '2026.1',
        sourceType: BankSourceType.importedExcel,
      );

      expect(result, isA<VaultSuccess<QuestionBank>>());
      final bank = (result as VaultSuccess<QuestionBank>).data;
      expect(bank.topics.length, 13);
      expect(bank.questions.length, 430);
      expect(bank.topics.first.order, 1);
      expect(bank.topics.last.order, 13);

      final firstQ = bank.questions.first;
      expect(firstQ.code, 'CD01_001');
      expect(firstQ.originalOrder, 1);
      expect(firstQ.correctOriginalIndex, 0);
      expect(firstQ.explanation, contains('Luật Đấu thầu 2023'));
      expect(firstQ.pointGroupKey, isNull);
    });

    test('parses optional Mã câu hỏi, Giải thích, and Nhóm cùng điểm columns', () {
      final bytes = buildSampleExcelBytes(includeExtendedColumns: true);

      final result = parser.parse(bytes, bankVersion: '2026.2');

      expect(result, isA<VaultSuccess<QuestionBank>>());
      final bank = (result as VaultSuccess<QuestionBank>).data;
      expect(bank.questions.first.code, 'Q_001');
      expect(bank.questions.first.explanation, 'Giải thích chi tiết cho câu 1.');
      expect(bank.questions.first.pointGroupKey, 'nhóm kiến thức 1_a');
      expect(
        bank.questionsByPointGroup['nhóm liên chuyên đề x']?.length,
        3,
      );
    });

    test('reports missing required header columns', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow([
        TextCellValue('STT'),
        TextCellValue('Câu hỏi'),
      ]);
      final bytes = excel.encode()!;

      final result = parser.parse(
        Uint8List.fromList(bytes),
        bankVersion: 'bad',
      );

      expect(result, isA<VaultError<QuestionBank>>());
      final failure = (result as VaultError<QuestionBank>).failure;
      expect(failure, isA<ExcelValidationFailure>());
    });

    test('reports exact row errors for invalid answer, empty stem, and duplicate code', () {
      final bytes = buildSampleExcelBytes(
        mutateSheet: (sheet) {
          // Row index 1 (Excel row 2): invalid answer letter 'E'
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1),
            TextCellValue('E'),
          );
          // Row index 2 (Excel row 3): empty question stem
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2),
            TextCellValue('   '),
          );
          // Row index 3 (Excel row 4): duplicate STT = 1
          sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
            IntCellValue(1),
          );
        },
      );

      final result = parser.parse(bytes, bankVersion: 'bad-rows');

      expect(result, isA<VaultError<QuestionBank>>());
      final failure = (result as VaultError<QuestionBank>).failure;
      expect(failure, isA<ExcelValidationFailure>());
      final rowErrors = (failure as ExcelValidationFailure).rowErrors;
      expect(rowErrors.any((e) => e.rowNumber == 2), isTrue);
      expect(rowErrors.any((e) => e.rowNumber == 3), isTrue);
      expect(rowErrors.any((e) => e.rowNumber == 4), isTrue);
    });

    test('rejects valid rows when fewer than 13 topics or fewer than 70 questions', () {
      final bytes = buildSampleExcelBytes(
        countsPerTopic: List<int>.filled(12, 6), // 12 topics, 72 questions
      );

      final result = parser.parse(bytes, bankVersion: 'too-few-topics');

      expect(result, isA<VaultError<QuestionBank>>());
      expect(
        (result as VaultError<QuestionBank>).failure,
        isA<InsufficientBankFailure>(),
      );

      final tooFewQuestionsBytes = buildSampleExcelBytes(
        countsPerTopic: List<int>.filled(13, 5), // 13 topics, 65 questions
      );
      final result2 = parser.parse(tooFewQuestionsBytes, bankVersion: 'too-few-q');
      expect(result2, isA<VaultError<QuestionBank>>());
      expect(
        (result2 as VaultError<QuestionBank>).failure,
        isA<InsufficientBankFailure>(),
      );
    });

    test('parses real-world headers ("Loại X:" and "Căn cứ pháp lý & Giải thích")', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      sheet.appendRow([
        TextCellValue('STT'),
        TextCellValue('Phân loại chuyên đề'),
        TextCellValue('Câu hỏi'),
        TextCellValue('Phương án A'),
        TextCellValue('Phương án B'),
        TextCellValue('Phương án C'),
        TextCellValue('Phương án D'),
        TextCellValue('Đáp án đúng'),
        TextCellValue('Căn cứ pháp lý & Giải thích'),
      ]);
      var idx = 1;
      for (var t = 13; t >= 1; t--) {
        for (var k = 0; k < 6; k++) {
          sheet.appendRow([
            IntCellValue(idx),
            TextCellValue('Loại $t: Chuyên đề $t'),
            TextCellValue('Câu $idx?'),
            TextCellValue('A'),
            TextCellValue('B'),
            TextCellValue('C'),
            TextCellValue('D'),
            TextCellValue('B'),
            TextCellValue('Điều $idx Luật Đấu thầu'),
          ]);
          idx++;
        }
      }
      final bytes = Uint8List.fromList(excel.encode()!);

      final result = parser.parse(bytes, bankVersion: 'real-header');

      expect(result, isA<VaultSuccess<QuestionBank>>());
      final bank = (result as VaultSuccess<QuestionBank>).data;
      expect(bank.topics.first.name, startsWith('Loại 1:'));
      expect(bank.topics.last.name, startsWith('Loại 13:'));
      expect(bank.questions.first.explanation, contains('Điều'));
    });
  });
}
