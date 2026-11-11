import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:excel/excel.dart';

/// Deterministic distribution across 13 topics summing to 430 questions.
const List<int> defaultTopicQuestionCounts = [
  40,
  35,
  38,
  32,
  45,
  30,
  28,
  34,
  36,
  26,
  30,
  28,
  28,
];

/// Builds a realistic `.xlsx` byte payload using the user's 9-column format
/// (plus optional extended columns).
Uint8List buildSampleExcelBytes({
  List<int> countsPerTopic = defaultTopicQuestionCounts,
  bool includeExtendedColumns = false,
  bool includeTrailingBlankRows = false,
  void Function(Sheet sheet)? mutateSheet,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  final sheet = excel[defaultSheet];

  final headers = <String>[
    'STT',
    'Phân loại chuyên đề',
    'Câu hỏi',
    'Phương án A',
    'Phương án B',
    'Phương án C',
    'Phương án D',
    'Đáp án đúng',
    'Căn cứ pháp lý',
    if (includeExtendedColumns) ...[
      'Mã câu hỏi',
      'Giải thích',
      'Nhóm cùng điểm',
    ],
  ];
  sheet.appendRow(headers.map<CellValue?>(TextCellValue.new).toList());

  var stt = 1;
  const answerLetters = ['A', 'B', 'C', 'D'];
  for (var t = 0; t < countsPerTopic.length; t++) {
    final topicOrder = t + 1;
    final topicName = 'Chuyên đề $topicOrder: Quy định đấu thầu phần $topicOrder';
    final count = countsPerTopic[t];
    for (var i = 0; i < count; i++) {
      final correct = answerLetters[(stt - 1) % 4];
      final row = <CellValue?>[
        IntCellValue(stt),
        TextCellValue(topicName),
        TextCellValue('Câu hỏi số $stt thuộc chuyên đề $topicOrder là gì?'),
        TextCellValue('Phương án A của câu $stt'),
        TextCellValue('Phương án B của câu $stt'),
        TextCellValue('Phương án C của câu $stt'),
        TextCellValue('Phương án D của câu $stt'),
        TextCellValue(correct),
        TextCellValue('Điều ${(stt % 50) + 1} Luật Đấu thầu 2023'),
      ];
      if (includeExtendedColumns) {
        final group = (i < 2)
            ? 'Nhóm kiến thức ${topicOrder}_A'
            : (i == 2 && topicOrder <= 3)
                ? 'Nhóm liên chuyên đề X'
                : '';
        row.addAll([
          TextCellValue('Q_${stt.toString().padLeft(3, '0')}'),
          TextCellValue('Giải thích chi tiết cho câu $stt.'),
          TextCellValue(group),
        ]);
      }
      sheet.appendRow(row);
      stt++;
    }
  }

  if (includeTrailingBlankRows) {
    sheet.appendRow([null, TextCellValue('   '), null]);
    sheet.appendRow([null, null, null]);
  }

  mutateSheet?.call(sheet);

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('Failed to encode sample Excel bytes');
  }
  return Uint8List.fromList(encoded);
}

/// Builds an in-memory [QuestionBank] matching the 430-question / 13-topic spec.
QuestionBank buildSampleQuestionBank({
  List<int> countsPerTopic = defaultTopicQuestionCounts,
  bool withPointGroups = true,
  String bankVersion = '2026.1-test',
  BankSourceType sourceType = BankSourceType.bundled,
}) {
  final topics = <Topic>[];
  final questions = <Question>[];
  var stt = 1;

  for (var t = 0; t < countsPerTopic.length; t++) {
    final order = t + 1;
    final topicId = 'CD${order.toString().padLeft(2, '0')}';
    final topicName = 'Chuyên đề $order: Quy định đấu thầu phần $order';
    final count = countsPerTopic[t];
    topics.add(
      Topic(
        id: topicId,
        order: order,
        name: topicName,
        questionCount: count,
      ),
    );

    for (var i = 0; i < count; i++) {
      final correctIdx = (stt - 1) % 4;
      String? groupKey;
      String? groupLabel;
      if (withPointGroups) {
        if (i < 3) {
          groupLabel = 'Hạn mức chuyên đề $order';
          groupKey = groupLabel.toLowerCase();
        } else if (i == 3 && order <= 4) {
          groupLabel = 'Ưu đãi nhà thầu chung';
          groupKey = groupLabel.toLowerCase();
        }
      }

      questions.add(
        Question(
          code: '${topicId}_${stt.toString().padLeft(3, '0')}',
          originalOrder: stt,
          topicId: topicId,
          topicName: topicName,
          stem: 'Câu hỏi $stt (Chuyên đề $order): Nội dung trắc nghiệm về đấu thầu?',
          options: [
            AnswerOption(originalLabel: 'A', text: 'Nội dung A câu $stt', originalIndex: 0),
            AnswerOption(originalLabel: 'B', text: 'Nội dung B câu $stt', originalIndex: 1),
            AnswerOption(originalLabel: 'C', text: 'Nội dung C câu $stt', originalIndex: 2),
            AnswerOption(originalLabel: 'D', text: 'Nội dung D câu $stt', originalIndex: 3),
          ],
          correctOriginalIndex: correctIdx,
          explanation: 'Căn cứ Điều ${(stt % 40) + 1} Luật Đấu thầu 2023.',
          legalReference: 'Điều ${(stt % 40) + 1} Luật Đấu thầu 2023',
          pointGroupKey: groupKey,
          pointGroupLabel: groupLabel,
        ),
      );
      stt++;
    }
  }

  return QuestionBank(
    bankVersion: bankVersion,
    importedAt: DateTime.utc(2026, 11, 11),
    sourceType: sourceType,
    topics: topics,
    questions: questions,
  );
}

