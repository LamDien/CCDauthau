import 'dart:io';

import 'package:args/args.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/question_bank.dart';
import 'package:cc_dau_thau/features/data_vault/domain/models/vault_result.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/bex_codec.dart';
import 'package:cc_dau_thau/features/data_vault/domain/services/excel_question_parser.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      help: 'Đường dẫn file Excel (.xlsx) ngân hàng câu hỏi.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'assets/vault/default_bank.bex',
      help: 'Đường dẫn xuất file mã hoá .bex.',
    )
    ..addOption(
      'version',
      abbr: 'v',
      help: 'Phiên bản ngân hàng câu hỏi (VD: 2026.1).',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Hiển thị hướng dẫn sử dụng.',
    );

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Lỗi tham số: ${e.message}');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (args.flag('help')) {
    stdout.writeln('Đóng gói ngân hàng câu hỏi Excel (.xlsx) sang định dạng mã hoá .bex');
    stdout.writeln(parser.usage);
    return;
  }

  final inputPath = args.option('input');
  if (inputPath == null || inputPath.trim().isEmpty) {
    stderr.writeln('Thiếu tham số bắt buộc --input <file.xlsx>');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Không tìm thấy tệp đầu vào: $inputPath');
    exitCode = 66;
    return;
  }

  final outputPath = args.option('output')!;
  final now = DateTime.now().toUtc();
  final version = args.option('version') ??
      '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

  final excelBytes = await inputFile.readAsBytes();
  const excelParser = ExcelQuestionParser();
  final parseResult = excelParser.parse(
    excelBytes,
    bankVersion: version,
    sourceType: BankSourceType.bundled,
    importedAt: now,
  );

  switch (parseResult) {
    case VaultError<QuestionBank>(:final failure):
      stderr.writeln('Kiểm tra dữ liệu thất bại [${failure.code}]: ${failure.message}');
      if (failure is ExcelValidationFailure) {
        for (final rowErr in failure.rowErrors.take(30)) {
          stderr.writeln('  - $rowErr');
        }
        if (failure.rowErrors.length > 30) {
          stderr.writeln('  ... và ${failure.rowErrors.length - 30} lỗi khác.');
        }
      }
      exitCode = 1;
      return;

    case VaultSuccess<QuestionBank>(:final data):
      final codec = BexCodec();
      final encoded = await codec.encode(data);
      final verify = await codec.decode(encoded, sourceType: BankSourceType.bundled);
      if (verify is VaultError<QuestionBank>) {
        stderr.writeln('Lỗi xác minh giải mã: ${verify.failure.message}');
        exitCode = 1;
        return;
      }

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(encoded, flush: true);

      stdout.writeln('Đóng gói thành công: $outputPath (${encoded.length} bytes)');
      stdout.writeln('Phiên bản: ${data.bankVersion} | Tổng câu: ${data.questions.length} | Số chuyên đề: ${data.topics.length}');
      stdout.writeln('Số nhóm "cùng một điểm": ${data.questionsByPointGroup.length}');
      for (final topic in data.topics) {
        stdout.writeln('  ${topic.order.toString().padLeft(2, '0')}. ${topic.name}: ${topic.questionCount} câu');
      }
  }
}

