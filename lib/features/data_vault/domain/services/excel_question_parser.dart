import 'dart:typed_data';

import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/point_group_normalizer.dart';
import 'package:excel/excel.dart';

enum _ColumnField {
  stt,
  questionCode,
  topic,
  stem,
  optionA,
  optionB,
  optionC,
  optionD,
  correctAnswer,
  legalReference,
  explanation,
  pointGroup,
}

final class _ParsedRawRow {
  const _ParsedRawRow({
    required this.excelRowNumber,
    required this.sttRaw,
    required this.sttInt,
    required this.explicitCode,
    required this.topicDisplayName,
    required this.stem,
    required this.optionsText,
    required this.correctIndex,
    required this.legalReference,
    required this.explanation,
    required this.pointGroupKey,
    required this.pointGroupLabel,
  });

  final int excelRowNumber;
  final String sttRaw;
  final int? sttInt;
  final String? explicitCode;
  final String topicDisplayName;
  final String stem;
  final List<String> optionsText;
  final int correctIndex;
  final String? legalReference;
  final String explanation;
  final String? pointGroupKey;
  final String? pointGroupLabel;
}

/// Parses and validates `.xlsx` question banks matching the 9-column standard
/// and optional metadata columns (`Mã câu hỏi`, `Giải thích`, `Nhóm cùng điểm`).
final class ExcelQuestionParser {
  const ExcelQuestionParser({
    this.requiredTopicCount = 13,
    this.minimumQuestionCount = 70,
  });

  final int requiredTopicCount;
  final int minimumQuestionCount;

  static final RegExp _topicOrderRegex = RegExp(
    r'^(?:chuyen de|cd|loai|phan|chuong|muc)?\s*0*(\d{1,2})\b',
    caseSensitive: false,
  );

  static const Map<String, _ColumnField> _headerAliases = {
    'stt': _ColumnField.stt,
    'so thu tu': _ColumnField.stt,
    'ma cau hoi': _ColumnField.questionCode,
    'ma': _ColumnField.questionCode,
    'phan loai chuyen de': _ColumnField.topic,
    'chuyen de': _ColumnField.topic,
    'ten chuyen de': _ColumnField.topic,
    'cau hoi': _ColumnField.stem,
    'noi dung': _ColumnField.stem,
    'noi dung cau hoi': _ColumnField.stem,
    'phuong an a': _ColumnField.optionA,
    'dap an a': _ColumnField.optionA,
    'phuong an b': _ColumnField.optionB,
    'dap an b': _ColumnField.optionB,
    'phuong an c': _ColumnField.optionC,
    'dap an c': _ColumnField.optionC,
    'phuong an d': _ColumnField.optionD,
    'dap an d': _ColumnField.optionD,
    'dap an dung': _ColumnField.correctAnswer,
    'dap an': _ColumnField.correctAnswer,
    'can cu phap ly': _ColumnField.legalReference,
    'can cu phap ly & giai thich': _ColumnField.legalReference,
    'can cu phap ly va giai thich': _ColumnField.legalReference,
    'can cu & giai thich': _ColumnField.legalReference,
    'can cu': _ColumnField.legalReference,
    'giai thich': _ColumnField.explanation,
    'nhom cung diem': _ColumnField.pointGroup,
    'cung mot diem': _ColumnField.pointGroup,
    'diem kien thuc': _ColumnField.pointGroup,
  };

  /// Decodes and validates [bytes] into an immutable [QuestionBank].
  VaultResult<QuestionBank> parse(
    Uint8List bytes, {
    required String bankVersion,
    BankSourceType sourceType = BankSourceType.importedExcel,
    DateTime? importedAt,
  }) {
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (e) {
      return VaultError(
        ExcelValidationFailure([
          ExcelRowError(
            rowNumber: 0,
            columnName: 'File Excel',
            message: 'Không thể đọc file .xlsx ($e).',
          ),
        ]),
      );
    }

    final sheet = _pickPrimarySheet(workbook);
    if (sheet == null || sheet.rows.isEmpty) {
      return VaultError(
        ExcelValidationFailure(const [
          ExcelRowError(
            rowNumber: 1,
            columnName: 'Sheet',
            message: 'File Excel không có dữ liệu.',
          ),
        ]),
      );
    }

    final headerMapping = _resolveHeaderColumns(sheet.rows.first);
    final headerErrors = _validateRequiredHeaders(headerMapping);
    if (headerErrors.isNotEmpty) {
      return VaultError(ExcelValidationFailure(headerErrors));
    }

    final rowErrors = <ExcelRowError>[];
    final rawRows = <_ParsedRawRow>[];
    final seenRowIdentity = <String>{};

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isBlankRow(row)) continue;

      final excelRowNumber = i + 1;
      final parsed = _parseRow(
        row: row,
        excelRowNumber: excelRowNumber,
        columns: headerMapping,
        errors: rowErrors,
        seenRowIdentity: seenRowIdentity,
      );
      if (parsed != null) {
        rawRows.add(parsed);
      }
    }

    if (rowErrors.isNotEmpty) {
      return VaultError(ExcelValidationFailure(rowErrors));
    }

    return _buildValidatedBank(
      rawRows: rawRows,
      bankVersion: bankVersion,
      sourceType: sourceType,
      importedAt: importedAt ?? DateTime.now().toUtc(),
    );
  }

  Sheet? _pickPrimarySheet(Excel workbook) {
    for (final entry in workbook.tables.entries) {
      if (_normalizeAscii(entry.key) == 'questions' && entry.value.rows.isNotEmpty) {
        return entry.value;
      }
    }
    for (final sheet in workbook.tables.values) {
      if (sheet.rows.isNotEmpty) return sheet;
    }
    return null;
  }

  Map<_ColumnField, int> _resolveHeaderColumns(List<Data?> headerRow) {
    final mapping = <_ColumnField, int>{};
    for (var col = 0; col < headerRow.length; col++) {
      final text = _cellText(headerRow[col]);
      if (text.isEmpty) continue;
      final normalized = _normalizeAscii(text);
      final field = _headerAliases[normalized];
      if (field != null && !mapping.containsKey(field)) {
        mapping[field] = col;
      }
    }
    return mapping;
  }

  List<ExcelRowError> _validateRequiredHeaders(Map<_ColumnField, int> cols) {
    final errors = <ExcelRowError>[];
    if (!cols.containsKey(_ColumnField.stt) &&
        !cols.containsKey(_ColumnField.questionCode)) {
      errors.add(const ExcelRowError(
        rowNumber: 1,
        columnName: 'STT / Mã câu hỏi',
        message: 'Thiếu cột STT hoặc Mã câu hỏi.',
      ));
    }

    const requiredColumns = <(_ColumnField, String)>[
      (_ColumnField.topic, 'Phân loại chuyên đề'),
      (_ColumnField.stem, 'Câu hỏi'),
      (_ColumnField.optionA, 'Phương án A'),
      (_ColumnField.optionB, 'Phương án B'),
      (_ColumnField.optionC, 'Phương án C'),
      (_ColumnField.optionD, 'Phương án D'),
      (_ColumnField.correctAnswer, 'Đáp án đúng'),
    ];

    for (final (field, label) in requiredColumns) {
      if (!cols.containsKey(field)) {
        errors.add(ExcelRowError(
          rowNumber: 1,
          columnName: label,
          message: 'Thiếu cột bắt buộc "$label".',
        ));
      }
    }
    return errors;
  }

  _ParsedRawRow? _parseRow({
    required List<Data?> row,
    required int excelRowNumber,
    required Map<_ColumnField, int> columns,
    required List<ExcelRowError> errors,
    required Set<String> seenRowIdentity,
  }) {
    String read(_ColumnField f) {
      final idx = columns[f];
      if (idx == null || idx >= row.length) return '';
      return _cellText(row[idx]);
    }

    final initialErrorCount = errors.length;
    final sttRaw = read(_ColumnField.stt);
    final explicitCodeRaw = read(_ColumnField.questionCode);
    final explicitCode = explicitCodeRaw.isEmpty ? null : explicitCodeRaw;
    final sttInt = int.tryParse(sttRaw);

    if (explicitCode == null && sttRaw.isEmpty) {
      errors.add(ExcelRowError(
        rowNumber: excelRowNumber,
        columnName: 'STT / Mã câu hỏi',
        message: 'Thiếu định danh câu hỏi.',
      ));
    }

    final topicName = PointGroupNormalizer.normalizeDisplayLabel(
          read(_ColumnField.topic),
        ) ??
        '';
    if (topicName.isEmpty) {
      errors.add(ExcelRowError(
        rowNumber: excelRowNumber,
        columnName: 'Phân loại chuyên đề',
        message: 'Không được để trống phân loại chuyên đề.',
      ));
    }

    final identityKey = explicitCode != null
        ? 'CODE::$explicitCode'
        : (topicName.isNotEmpty && sttRaw.isNotEmpty)
            ? 'STT::${_normalizeAscii(topicName)}::${sttInt?.toString() ?? sttRaw}'
            : null;
    if (identityKey != null && !seenRowIdentity.add(identityKey)) {
      errors.add(ExcelRowError(
        rowNumber: excelRowNumber,
        columnName: explicitCode != null ? 'Mã câu hỏi' : 'STT',
        message:
            'Trùng định danh câu hỏi "${explicitCode ?? sttRaw}" trong chuyên đề.',
      ));
    }

    final stem = read(_ColumnField.stem);
    if (stem.isEmpty) {
      errors.add(ExcelRowError(
        rowNumber: excelRowNumber,
        columnName: 'Câu hỏi',
        message: 'Nội dung câu hỏi không được để trống.',
      ));
    }

    final optA = read(_ColumnField.optionA);
    final optB = read(_ColumnField.optionB);
    final optC = read(_ColumnField.optionC);
    final optD = read(_ColumnField.optionD);
    final optionPairs = [
      (optA, 'Phương án A'),
      (optB, 'Phương án B'),
      (optC, 'Phương án C'),
      (optD, 'Phương án D'),
    ];
    for (final (optText, colLabel) in optionPairs) {
      if (optText.isEmpty) {
        errors.add(ExcelRowError(
          rowNumber: excelRowNumber,
          columnName: colLabel,
          message: '$colLabel không được để trống.',
        ));
      }
    }

    final correctIdx = _parseCorrectOptionIndex(read(_ColumnField.correctAnswer));
    if (correctIdx == null) {
      errors.add(ExcelRowError(
        rowNumber: excelRowNumber,
        columnName: 'Đáp án đúng',
        message: 'Giá trị phải là một trong các chữ cái A, B, C hoặc D.',
      ));
    }

    if (errors.length > initialErrorCount) {
      return null;
    }

    final legalRaw = read(_ColumnField.legalReference);
    final legalRef = legalRaw.isEmpty ? null : legalRaw;
    final explanationRaw = read(_ColumnField.explanation);
    final explanation = explanationRaw.isNotEmpty ? explanationRaw : (legalRef ?? '');
    final pointGroupRaw = read(_ColumnField.pointGroup);

    return _ParsedRawRow(
      excelRowNumber: excelRowNumber,
      sttRaw: sttRaw,
      sttInt: sttInt,
      explicitCode: explicitCode,
      topicDisplayName: topicName,
      stem: stem,
      optionsText: [optA, optB, optC, optD],
      correctIndex: correctIdx!,
      legalReference: legalRef,
      explanation: explanation,
      pointGroupKey: PointGroupNormalizer.normalizeKey(pointGroupRaw),
      pointGroupLabel: PointGroupNormalizer.normalizeDisplayLabel(pointGroupRaw),
    );
  }

  VaultResult<QuestionBank> _buildValidatedBank({
    required List<_ParsedRawRow> rawRows,
    required String bankVersion,
    required BankSourceType sourceType,
    required DateTime importedAt,
  }) {
    final topicFirstSeen = <String, int>{};
    final topicDisplayNames = <String, String>{};
    final topicCounts = <String, int>{};

    for (final row in rawRows) {
      final normTopic = _normalizeAscii(row.topicDisplayName);
      topicFirstSeen.putIfAbsent(normTopic, () => topicFirstSeen.length);
      topicDisplayNames.putIfAbsent(normTopic, () => row.topicDisplayName);
      topicCounts[normTopic] = (topicCounts[normTopic] ?? 0) + 1;
    }

    // Order topics deterministically by extracted number if available, then appearance.
    final sortedTopicKeys = topicFirstSeen.keys.toList()
      ..sort((a, b) {
        final orderA = _extractTopicOrder(topicDisplayNames[a]!);
        final orderB = _extractTopicOrder(topicDisplayNames[b]!);
        if (orderA != null && orderB != null) {
          final cmp = orderA.compareTo(orderB);
          if (cmp != 0) return cmp;
        } else if (orderA != null) {
          return -1;
        } else if (orderB != null) {
          return 1;
        }
        return topicFirstSeen[a]!.compareTo(topicFirstSeen[b]!);
      });

    final topicIdByNorm = <String, String>{};
    final topics = <Topic>[];
    for (var idx = 0; idx < sortedTopicKeys.length; idx++) {
      final normKey = sortedTopicKeys[idx];
      final order = idx + 1;
      final topicId = 'CD${order.toString().padLeft(2, '0')}';
      topicIdByNorm[normKey] = topicId;
      topics.add(
        Topic(
          id: topicId,
          order: order,
          name: topicDisplayNames[normKey]!,
          questionCount: topicCounts[normKey]!,
        ),
      );
    }

    final seenCodes = <String>{};
    final duplicateErrors = <ExcelRowError>[];
    final questions = <Question>[];
    const labels = ['A', 'B', 'C', 'D'];

    for (final row in rawRows) {
      final normTopic = _normalizeAscii(row.topicDisplayName);
      final topicId = topicIdByNorm[normTopic]!;
      final topicName = topicDisplayNames[normTopic]!;

      final code = row.explicitCode ?? _buildGeneratedCode(topicId, row.sttRaw);
      if (!seenCodes.add(code)) {
        duplicateErrors.add(
          ExcelRowError(
            rowNumber: row.excelRowNumber,
            columnName: row.explicitCode != null ? 'Mã câu hỏi' : 'STT',
            message: 'Trùng định danh câu hỏi "$code" trong chuyên đề.',
          ),
        );
        continue;
      }

      final options = List<AnswerOption>.generate(
        4,
        (i) => AnswerOption(
          originalLabel: labels[i],
          text: row.optionsText[i],
          originalIndex: i,
        ),
      );

      questions.add(
        Question(
          code: code,
          originalOrder: row.sttInt,
          topicId: topicId,
          topicName: topicName,
          stem: row.stem,
          options: options,
          correctOriginalIndex: row.correctIndex,
          explanation: row.explanation,
          legalReference: row.legalReference,
          pointGroupKey: row.pointGroupKey,
          pointGroupLabel: row.pointGroupLabel,
        ),
      );
    }

    if (duplicateErrors.isNotEmpty) {
      return VaultError(ExcelValidationFailure(duplicateErrors));
    }

    if (topics.length != requiredTopicCount ||
        questions.length < minimumQuestionCount) {
      return VaultError(
        InsufficientBankFailure(
          'Ngân hàng câu hỏi phải có đủ $requiredTopicCount chuyên đề và tối thiểu '
          '$minimumQuestionCount câu hỏi (hiện có ${topics.length} chuyên đề, '
          '${questions.length} câu).',
        ),
      );
    }

    return VaultSuccess(
      QuestionBank(
        bankVersion: bankVersion,
        importedAt: importedAt,
        sourceType: sourceType,
        topics: topics,
        questions: questions,
      ),
    );
  }

  String _buildGeneratedCode(String topicId, String sttRaw) {
    final numeric = int.tryParse(sttRaw);
    if (numeric != null) {
      return '${topicId}_${numeric.toString().padLeft(3, '0')}';
    }
    final sanitized = sttRaw.replaceAll(RegExp(r'\s+'), '_');
    return '${topicId}_$sanitized';
  }

  int? _extractTopicOrder(String topicName) {
    final normalized = _normalizeAscii(topicName);
    final match = _topicOrderRegex.firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  int? _parseCorrectOptionIndex(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[.)]+$'), '').trim();
    return switch (cleaned) {
      'A' => 0,
      'B' => 1,
      'C' => 2,
      'D' => 3,
      _ => null,
    };
  }

  bool _isBlankRow(List<Data?> row) {
    for (final cell in row) {
      if (_cellText(cell).isNotEmpty) return false;
    }
    return true;
  }

  String _cellText(Data? cell) {
    final val = cell?.value;
    if (val == null) return '';
    return switch (val) {
      TextCellValue() => val.value.toString().trim(),
      IntCellValue() => val.value.toString().trim(),
      DoubleCellValue() => (val.value == val.value.toInt()
              ? val.value.toInt().toString()
              : val.value.toString())
          .trim(),
      BoolCellValue() => val.value.toString().trim(),
      FormulaCellValue() => val.formula.trim(),
      DateCellValue() => val.toString().trim(),
      TimeCellValue() => val.toString().trim(),
      DateTimeCellValue() => val.toString().trim(),
    };
  }

  String _normalizeAscii(String input) {
    final lower = input.toLowerCase().trim();
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      sb.write(_vietnameseAsciiMap[lower[i]] ?? lower[i]);
    }
    return sb
        .toString()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const Map<String, String> _vietnameseAsciiMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
  };
}
