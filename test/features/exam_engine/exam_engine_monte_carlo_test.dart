import 'dart:math';

import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_models.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/models/exam_result.dart';
import 'package:cc_dau_thau/features/exam_engine/domain/services/exam_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/sample_bank_builder.dart';

void main() {
  test('Monte Carlo: 10,000 generated exams satisfy 70 questions, quotas, and zero duplicate pointGroupKey', () {
    final bank = buildSampleQuestionBank(
      // Real 430-question topic counts from ngan_hang_cau_hoi_dau_thau.xlsx
      countsPerTopic: const [30, 13, 72, 17, 13, 21, 16, 23, 64, 40, 18, 83, 20],
      withPointGroups: true,
    );
    final engine = ExamEngine();
    final rng = Random(20261111);
    final stopwatch = Stopwatch()..start();

    for (var i = 0; i < 10000; i++) {
      final result = engine.generateMockExam(bank, random: rng);
      expect(result, isA<ExamSuccess<GeneratedExam>>());
      final exam = (result as ExamSuccess<GeneratedExam>).data;

      expect(exam.items.length, 70);

      final seenCodes = <String>{};
      final seenPointGroups = <String>{};
      for (final item in exam.items) {
        expect(seenCodes.add(item.questionCode), isTrue);
        if (item.pointGroupKey != null) {
          expect(seenPointGroups.add(item.pointGroupKey!), isTrue);
        }
        final orig = bank.questionsByCode[item.questionCode]!;
        expect(
          item.shuffledOptions[item.correctDisplayIndex].text,
          orig.correctOption.text,
        );
      }
    }

    stopwatch.stop();
    // 10,000 exams should stay comfortably well under 10s (avg < 1ms/exam).
    expect(stopwatch.elapsedMilliseconds, lessThan(10000));
  });
}

